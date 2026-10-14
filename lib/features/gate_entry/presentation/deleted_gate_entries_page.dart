import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/theme_toggle_button.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/gate_entry_repository_impl.dart';
import '../domain/models/deleted_gate_entry.dart';

/// Admin only: gate entries that were deleted, with who deleted them, when
/// and why. Read-only — a deleted entry cannot be restored from here.
class DeletedGateEntriesPage extends ConsumerStatefulWidget {
  const DeletedGateEntriesPage({super.key});

  @override
  ConsumerState<DeletedGateEntriesPage> createState() =>
      _DeletedGateEntriesPageState();
}

class _DeletedGateEntriesPageState
    extends ConsumerState<DeletedGateEntriesPage> {
  static const _pageSize = 25;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _search;
  int _page = 1;
  bool _loading = true;
  String? _error;
  DeletedGateEntryPage? _result;
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
        .getDeletedGateEntries(search: _search, page: _page, limit: _pageSize);
    // A slower, older request must not overwrite a newer search.
    if (!mounted || seq != _requestSeq) return;
    setState(() {
      _loading = false;
      if (response.success && response.data != null) {
        _result = response.data;
      } else {
        _error = response.message.isNotEmpty
            ? response.message
            : 'Could not load deleted gate entries.';
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

  void _goToPage(int page) {
    _page = page;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final result = _result;
    final entries = result?.entries ?? const <DeletedGateEntry>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            RibbonAccentBar(height: 22),
            SizedBox(width: 10),
            Flexible(child: Text('Deleted Entries')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const ThemeToggleButton(),
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
              title: 'Deleted Gate Entries',
              subtitle: result == null
                  ? 'Entries removed by an admin, with the reason given.'
                  : '${result.total} deleted '
                      '${result.total == 1 ? 'entry' : 'entries'} — '
                      'removed by an admin, with the reason given.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    'Search gate entry no, invoice, vendor, vehicle, reason…',
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
            else if (entries.isEmpty)
              _MessageCard(
                icon: Icons.delete_sweep_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                text: _search == null
                    ? 'No gate entries have been deleted.'
                    : 'No deleted entries match "$_search".',
              )
            else ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeletedEntryCard(
                    entry: entry,
                    onTap: () => _showDetails(context, entry),
                  ),
                ),
              if ((result?.totalPages ?? 0) > 1)
                _Pager(
                  page: result!.page,
                  totalPages: result.totalPages,
                  onPage: _loading ? null : _goToPage,
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, DeletedGateEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeletedEntryDetailsDialog(entry: entry),
    );
  }
}

final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
String _fmt(DateTime? at) => at == null ? '—' : _dateTime.format(at.toLocal());

String _statusLabel(String? status) {
  switch (status) {
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
    case null:
      return '—';
    default:
      return status;
  }
}

class _DeletedEntryCard extends StatelessWidget {
  const _DeletedEntryCard({required this.entry, required this.onTap});

  final DeletedGateEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final muted = theme.colorScheme.onSurfaceVariant;
    final vendor = entry.vendorName ?? entry.vendorCode;

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
                child: Text(
                  entry.gateEntryNo,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _Chip(label: 'Deleted', color: error),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Fact(icon: Icons.receipt_long_outlined, text: entry.challanNo ?? '—'),
              if (vendor != null) _Fact(icon: Icons.store_outlined, text: vendor),
              if (entry.vehicleNo != null)
                _Fact(icon: Icons.local_shipping_outlined, text: entry.vehicleNo!),
              _Fact(
                  icon: Icons.login_rounded,
                  text: '${entry.gateDirection} · ${_fmt(entry.gateTimestamp)}'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Reason: ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: error),
                ),
                TextSpan(text: entry.reason),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleted by ${entry.deletedBy ?? 'unknown'} · ${_fmt(entry.deletedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _DeletedEntryDetailsDialog extends StatelessWidget {
  const _DeletedEntryDetailsDialog({required this.entry});

  final DeletedGateEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final qty = NumberFormat('#,##0.###');

    final rows = <(String, String?)>[
      ('Direction', entry.gateDirection),
      ('Gate date & time', _fmt(entry.gateTimestamp)),
      ('Invoice / Challan', entry.challanNo),
      ('Document date', entry.documentDate),
      ('Vendor', [entry.vendorName, entry.vendorCode].whereType<String>().join(' · ')),
      ('Vehicle', entry.vehicleNo),
      ('Transporter', entry.transporterName),
      ('LR number', entry.lrNumber),
      ('Driver contact', entry.driverContactNo),
      ('Status when deleted', _statusLabel(entry.status)),
      if (entry.reconciliationStatus != null)
        ('Reconciliation', [entry.reconciliationStatus, entry.matchedGrnNumber]
            .whereType<String>()
            .join(' · ')),
      if (entry.gateOutTimestamp != null) ('Gate out', _fmt(entry.gateOutTimestamp)),
      ('Created by', entry.createdBy),
      if (entry.attachmentCount > 0) ('Attachments', '${entry.attachmentCount}'),
      ('Remarks', entry.remarks),
    ];

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(entry.gateEntryNo)),
          _Chip(label: 'Deleted', color: error),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: error.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: error, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    SelectableText(entry.reason),
                    const SizedBox(height: 8),
                    Text(
                      'Deleted by ${entry.deletedBy ?? 'unknown'} on ${_fmt(entry.deletedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final (label, value) in rows)
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        Expanded(child: SelectableText(value)),
                      ],
                    ),
                  ),
              if (entry.items.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Items',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final item in entry.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      [
                        if (item.poNumber != null) 'PO ${item.poNumber}',
                        item.materialCode ?? 'No material code',
                        if (item.materialDescription != null)
                          item.materialDescription!,
                        if (item.challanQty != null)
                          '${qty.format(item.challanQty)} ${item.uom ?? ''}'.trim(),
                      ].join(' · '),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
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
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
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
