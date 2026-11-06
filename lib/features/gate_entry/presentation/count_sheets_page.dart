import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/gate_entry_repository_impl.dart';
import '../domain/models/count_sheet.dart';
import '../domain/models/gate_entry.dart';
import 'count_sheet_print.dart';
import 'gate_entry_detail_page.dart';
import 'count_sheet_gate_out.dart';

final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
String _fmt(DateTime? at) => at == null ? '—' : _dateTime.format(at.toLocal());

final _qty = NumberFormat('#,##0.###');

/// Opens one count sheet's page.
void openCountSheet(BuildContext context, String countSheetNo) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CountSheetDetailPage(countSheetNo: countSheetNo),
  ));
}

/// Every count sheet with gate entries, newest first. A count sheet is one
/// save of Create Gate Entry: one vehicle and all of its invoices.
class CountSheetsPage extends ConsumerStatefulWidget {
  const CountSheetsPage({super.key});

  @override
  ConsumerState<CountSheetsPage> createState() => _CountSheetsPageState();
}

class _CountSheetsPageState extends ConsumerState<CountSheetsPage> {
  static const _pageSize = 25;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _search;
  int _page = 1;
  bool _loading = true;
  String? _error;
  CountSheetPage? _result;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ref
        .read(gateEntryRepositoryProvider)
        .getCountSheets(search: _search, page: _page, limit: _pageSize);
    // A slower, older request must not overwrite a newer search.
    if (!mounted || seq != _requestSeq) return;
    setState(() {
      _loading = false;
      if (response.success && response.data != null) {
        _result = response.data;
      } else {
        _error = response.message.isNotEmpty
            ? response.message
            : 'Could not load count sheets.';
      }
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search = value.trim().isEmpty ? null : value.trim();
      _page = 1;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final result = _result;
    final sheets = result?.sheets ?? const <CountSheetSummary>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            RibbonAccentBar(height: 22),
            SizedBox(width: 10),
            Flexible(child: Text('Count Sheets')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              mob ? 16 : 24, 16, mob ? 16 : 24, mob ? 96 : 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Count Sheets',
              subtitle: result == null
                  ? 'One count sheet per vehicle, with all of its invoices.'
                  : '${result.total} count sheet${result.total == 1 ? '' : 's'}'
                      ' — one per vehicle, with all of its invoices.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    'Search count sheet no, invoice, vendor, vehicle, PO, material…',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading && result == null)
              ...List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(width: double.infinity, height: 120),
                ),
              )
            else if (_error != null)
              _MessageCard(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                text: _error!,
                action: TextButton(
                    onPressed: _load, child: const Text('Try again')),
              )
            else if (sheets.isEmpty)
              _MessageCard(
                icon: Icons.fact_check_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                text: _search == null
                    ? 'No count sheets yet. Every new gate entry is saved on one.'
                    : 'No count sheet matches "$_search".',
              )
            else ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              for (final sheet in sheets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CountSheetCard(
                    sheet: sheet,
                    onTap: () => openCountSheet(context, sheet.countSheetNo),
                    onPrint: () =>
                        printCountSheet(context, ref, sheet.countSheetNo),
                    // The vehicle is still inside: gate out every invoice of
                    // the sheet together.
                    onGateOut: sheet.canGateOut && canRecordGateOut(ref)
                        ? () async {
                            final done = await confirmAndGateOutCountSheet(
                              context,
                              ref,
                              countSheetNo: sheet.countSheetNo,
                              vehicleNo: sheet.vehicleNos,
                              invoiceCount: sheet.pendingGateOutCount,
                              vendors: sheet.vendorNames,
                              minutesInside: sheet.gateTimestamp == null
                                  ? null
                                  : DateTime.now()
                                      .difference(sheet.gateTimestamp!)
                                      .inMinutes,
                            );
                            if (done && mounted) _load();
                          }
                        : null,
                  ),
                ),
              if ((result?.totalPages ?? 0) > 1)
                _Pager(
                  page: result!.page,
                  totalPages: result.totalPages,
                  onPage: _loading
                      ? null
                      : (p) {
                          _page = p;
                          _load();
                        },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountSheetCard extends StatelessWidget {
  const _CountSheetCard({
    required this.sheet,
    required this.onTap,
    required this.onPrint,
    this.onGateOut,
  });

  final CountSheetSummary sheet;
  final VoidCallback onTap;
  final VoidCallback onPrint;
  final VoidCallback? onGateOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final out = sheet.allGatedOut;
    return VistarCard(
      onTap: onTap,
      glowOnHover: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Count Sheet ${sheet.countSheetNo}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _Chip(
                label: out ? 'Gated out' : 'Inside',
                color: out ? Colors.grey.shade700 : Colors.green.shade700,
              ),
              IconButton(
                tooltip: 'Print count sheet',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.print_outlined, size: 20),
                onPressed: onPrint,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Fact(
                  icon: Icons.receipt_long_outlined,
                  text:
                      '${sheet.entryCount} invoice${sheet.entryCount == 1 ? '' : 's'}'),
              _Fact(
                  icon: Icons.inventory_2_outlined,
                  text:
                      '${sheet.itemCount} item${sheet.itemCount == 1 ? '' : 's'} · Qty ${_qty.format(sheet.totalQuantity)}'),
              if (sheet.vehicleNos != null)
                _Fact(icon: Icons.local_shipping_outlined, text: sheet.vehicleNos!),
              if (sheet.vendorNames != null)
                _Fact(icon: Icons.store_outlined, text: sheet.vendorNames!),
              _Fact(
                  icon: Icons.login_rounded,
                  text: '${sheet.gateDirection} · ${_fmt(sheet.gateTimestamp)}'),
            ],
          ),
          if (sheet.challanNos != null) ...[
            const SizedBox(height: 6),
            Text(
              'Invoices: ${sheet.challanNos}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (sheet.createdBy != null) ...[
            const SizedBox(height: 4),
            Text(
              'By ${sheet.createdBy}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (onGateOut != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _GateOutVehicleButton(onPressed: onGateOut!),
            ),
          ],
        ],
      ),
    );
  }
}

/// One count sheet: the vehicle, and every gate entry (invoice) on it with
/// its items. Tap an entry for its full details and actions.
class CountSheetDetailPage extends ConsumerStatefulWidget {
  const CountSheetDetailPage({super.key, required this.countSheetNo});

  final String countSheetNo;

  @override
  ConsumerState<CountSheetDetailPage> createState() =>
      _CountSheetDetailPageState();
}

class _CountSheetDetailPageState extends ConsumerState<CountSheetDetailPage> {
  bool _loading = true;
  String? _error;
  List<GateEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ref
        .read(gateEntryRepositoryProvider)
        .getCountSheetEntries(widget.countSheetNo);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (response.success && response.data != null) {
        _entries = response.data!;
      } else {
        _error = response.message.isNotEmpty
            ? response.message
            : 'Could not load this count sheet.';
      }
    });
  }

  /// Inward invoices of this sheet still waiting for their gate out.
  List<GateEntry> get _inside => _entries
      .where((e) =>
          e.gateMovement == GateMovement.inMovement &&
          e.gateOutTimestamp == null)
      .toList();

  Future<void> _gateOutVehicle() async {
    final inside = _inside;
    if (inside.isEmpty) return;
    final gateIn = inside
        .map((e) => e.gateTimestamp)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final done = await confirmAndGateOutCountSheet(
      context,
      ref,
      countSheetNo: widget.countSheetNo,
      vehicleNo: _distinct(inside.map((e) => e.vehicleNo)),
      invoiceCount: inside.length,
      vendors: _distinct(inside.map((e) => e.vendorName)),
      minutesInside:
          gateIn == null ? null : DateTime.now().difference(gateIn).inMinutes,
    );
    if (done && mounted) _load();
  }

  Future<void> _openEntry(GateEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GateEntryDetailPage(entryId: entry.id),
    ));
    // The entry may have been edited, gated out or deleted there.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Count Sheet ${widget.countSheetNo}'),
        actions: [
          // The Receipt and Put Away Sheet for this vehicle.
          if (_entries.isNotEmpty) ...[
            isMobile(context)
                ? IconButton(
                    tooltip: 'View count sheet',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () => viewCountSheet(
                        context, ref, widget.countSheetNo,
                        entries: _entries),
                  )
                : TextButton.icon(
                    onPressed: () => viewCountSheet(
                        context, ref, widget.countSheetNo,
                        entries: _entries),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('View'),
                  ),
            isMobile(context)
                ? IconButton(
                    tooltip: 'Print count sheet',
                    icon: const Icon(Icons.print_outlined),
                    onPressed: () => printCountSheet(
                        context, ref, widget.countSheetNo,
                        entries: _entries),
                  )
                : FilledButton.icon(
                    onPressed: () => printCountSheet(
                        context, ref, widget.countSheetNo,
                        entries: _entries),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Count Sheet'),
                  ),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              mob ? 16 : 24, 16, mob ? 16 : 24, mob ? 96 : 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading && _entries.isEmpty)
                    ...List.generate(
                      3,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child:
                            SkeletonLoader(width: double.infinity, height: 110),
                      ),
                    )
                  else if (_error != null)
                    _MessageCard(
                      icon: Icons.error_outline,
                      color: theme.colorScheme.error,
                      text: _error!,
                      action: TextButton(
                          onPressed: _load, child: const Text('Try again')),
                    )
                  else if (_entries.isEmpty)
                    _MessageCard(
                      icon: Icons.fact_check_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      text:
                          'No gate entries on count sheet ${widget.countSheetNo}.',
                    )
                  else ...[
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    _SheetHeader(
                        countSheetNo: widget.countSheetNo, entries: _entries),
                    if (_inside.isNotEmpty && canRecordGateOut(ref)) ...[
                      const SizedBox(height: 12),
                      _GateOutVehicleButton(
                        onPressed: _gateOutVehicle,
                        expanded: true,
                        label: 'Gate Out Vehicle  ·  ${_inside.length} '
                            'invoice${_inside.length == 1 ? '' : 's'} inside',
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '${_entries.length} invoice${_entries.length == 1 ? '' : 's'} on this count sheet',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in _entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SheetEntryCard(
                            entry: entry, onTap: () => _openEntry(entry)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gate out the vehicle of a count sheet (every invoice still inside).
class _GateOutVehicleButton extends StatelessWidget {
  const _GateOutVehicleButton({
    required this.onPressed,
    this.expanded = false,
    this.label = 'Gate Out Vehicle',
  });

  final VoidCallback onPressed;
  final bool expanded;
  final String label;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: expanded ? 14 : 10),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: Text(label),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

String? _distinct(Iterable<String> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final v in values) {
    final t = v.trim();
    if (t.isNotEmpty && seen.add(t.toUpperCase())) out.add(t);
  }
  return out.isEmpty ? null : out.join(', ');
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.countSheetNo, required this.entries});

  final String countSheetNo;
  final List<GateEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final first = entries.first;
    final items = entries.expand((e) => e.items).toList();
    final totalQty = items.fold<num>(0, (sum, i) => sum + i.challanQty);
    final gatedOut = entries.where((e) => e.gateOutTimestamp != null).length;
    final gateOut = entries
        .map((e) => e.gateOutTimestamp)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    final rows = <(String, String?)>[
      ('Vehicle', _distinct(entries.map((e) => e.vehicleNo))),
      (
        'Vendor',
        _distinct(entries.map((e) => [e.vendorName, e.vendorCode]
            .where((s) => s.trim().isNotEmpty)
            .join(' · ')))
      ),
      ('Transporter', _distinct(entries.map((e) => e.transporterName))),
      ('LR number', _distinct(entries.map((e) => e.lrNumber))),
      ('Driver contact', _distinct(entries.map((e) => e.driverContactNo))),
      (
        'Direction',
        first.gateMovement == GateMovement.inMovement ? 'Gate In' : 'Gate Out'
      ),
      ('Gate in', _fmt(first.gateTimestamp)),
      (
        'Gate out',
        gatedOut == 0
            ? 'Still inside'
            : gatedOut < entries.length
                ? '$gatedOut of ${entries.length} invoices · last ${_fmt(gateOut)}'
                : _fmt(gateOut)
      ),
      (
        'Totals',
        '${entries.length} invoices · ${items.length} items · Qty ${_qty.format(totalQty)}'
      ),
    ];

    return VistarCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: accent),
              const SizedBox(width: 10),
              Text('COUNT SHEET NO.',
                  style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            countSheetNo,
            style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          for (final (label, value) in rows)
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text(value,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SheetEntryCard extends StatelessWidget {
  const _SheetEntryCard({required this.entry, required this.onTap});

  final GateEntry entry;
  final VoidCallback onTap;

  static String _statusLabel(GateEntry e) {
    if (e.gateOutTimestamp != null) return 'Gated out';
    switch (e.status) {
      case 'inward_created':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'approved':
        return 'Approved';
      case 'closed':
        return 'Closed';
      case 'exception':
        return 'Exception';
      default:
        return e.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return VistarCard(
      onTap: onTap,
      glowOnHover: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice ${entry.challanNo}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if ((entry.gateEntryNo ?? '').isNotEmpty)
                      Text(entry.gateEntryNo!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted)),
                  ],
                ),
              ),
              _Chip(label: _statusLabel(entry), color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
          if (entry.items.isNotEmpty) ...[
            const Divider(height: 18),
            for (final item in entry.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if (item.poNumber.trim().isNotEmpty)
                            'PO ${item.poNumber}',
                          if (item.materialCode.trim().isNotEmpty)
                            item.materialCode,
                        ].join('  ·  ').ifEmpty('—'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${_qty.format(item.challanQty)} ${item.uom}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final void Function(int page)? onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: onPage != null && page > 1 ? () => onPage!(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $page of $totalPages'),
        IconButton(
          tooltip: 'Next page',
          onPressed: onPage != null && page < totalPages
              ? () => onPage!(page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
