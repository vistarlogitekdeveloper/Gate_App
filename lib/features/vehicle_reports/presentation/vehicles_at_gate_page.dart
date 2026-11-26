import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../../gate_entry/presentation/count_sheets_page.dart';
import '../../gate_entry/presentation/gate_entry_form_page.dart';
import '../data/vehicle_report_repository.dart';
import '../domain/vehicle_report.dart';
import 'report_qr_page.dart';

final _time = DateFormat('hh:mm a');
final _dateTime = DateFormat('dd MMM, hh:mm a');
String _fmt(DateTime? at) => at == null ? '—' : _dateTime.format(at);

/// Who may make the gate entry of a waiting vehicle or remove it (the server
/// allows the same roles).
bool _canAct(UserRole? role) =>
    role == UserRole.gateSecurity ||
    role == UserRole.warehouseExecutive ||
    role == UserRole.admin;

/// Vehicles that reported outside the gate (QR code form) and are waiting for
/// their gate entry, and the history of those that went in, were removed or
/// expired.
class VehiclesAtGatePage extends ConsumerStatefulWidget {
  const VehiclesAtGatePage({super.key});

  @override
  ConsumerState<VehiclesAtGatePage> createState() => _VehiclesAtGatePageState();
}

class _VehiclesAtGatePageState extends ConsumerState<VehiclesAtGatePage>
    with SingleTickerProviderStateMixin {
  static const _historyPageSize = 25;

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefresh;
  String? _search;
  int _seq = 0;

  bool _loading = true;
  String? _error;
  List<VehicleReport> _waiting = const [];
  List<VehicleReport> _history = const [];
  int _historyPage = 1;
  int _historyPages = 0;
  int _historyTotal = 0;
  bool _loadingMore = false;

  bool get _onHistory => _tabs.index == 1;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) _load();
      });
    _load();
    // The list fills from drivers' phones: keep it current on its own.
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_onHistory) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final seq = ++_seq;
    final history = _onHistory;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(vehicleReportRepositoryProvider);
      final page = await repo.list(
          history: history, search: _search, page: 1, limit: _historyPageSize);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = null;
        if (history) {
          _history = page.reports;
          _historyPage = page.page;
          _historyPages = page.totalPages;
          _historyTotal = page.total;
        } else {
          _waiting = page.reports;
        }
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (!quiet) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_loadingMore || _historyPage >= _historyPages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(vehicleReportRepositoryProvider).list(
          history: true,
          search: _search,
          page: _historyPage + 1,
          limit: _historyPageSize);
      if (!mounted) return;
      setState(() {
        _history = [..._history, ...page.reports];
        _historyPage = page.page;
        _historyPages = page.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search = value.trim().isEmpty ? null : value.trim();
      _load();
    });
  }

  Future<void> _makeGateEntry(VehicleReport r) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GateEntryFormPage(fromReport: r),
    ));
    if (mounted) _load();
  }

  Future<void> _remove(VehicleReport r) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${r.vehicleNo}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('It leaves the At Gate list and goes to History.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in const ['Vehicle left', 'Wrong gate', 'Reported twice'])
                  ActionChip(label: Text(s), onPressed: () => reasonCtrl.text = s),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = reasonCtrl.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    try {
      await ref.read(vehicleReportRepositoryProvider).remove(r.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${r.vehicleNo} removed from At Gate'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;
    final canAct = _canAct(role);
    final theme = Theme.of(context);
    final list = _onHistory ? _history : _waiting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            RibbonAccentBar(height: 22),
            SizedBox(width: 10),
            Flexible(child: Text('Vehicles at Gate')),
          ],
        ),
        actions: [
          if (role == UserRole.admin)
            mob
                ? IconButton(
                    tooltip: 'Reporting QR code',
                    icon: const Icon(Icons.qr_code_2_rounded),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportQrPage())),
                  )
                : TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportQrPage())),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Reporting QR'),
                  ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Waiting${_waiting.isEmpty ? '' : ' (${_waiting.length})'}'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, mob ? 96 : 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: _onHistory ? 'History' : 'Waiting outside the gate',
              subtitle: _onHistory
                  ? '$_historyTotal vehicle${_historyTotal == 1 ? '' : 's'} — entered, removed or expired.'
                  : 'Reported by drivers with the QR code. Tap Gate Entry when the vehicle comes in.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search vehicle, vendor, driver, mobile, gate entry, count sheet…',
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
            if (_loading && list.isEmpty)
              ...List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(width: double.infinity, height: 120),
                ),
              )
            else if (_error != null)
              _Message(
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
                text: _error!,
                action: TextButton(onPressed: _load, child: const Text('Try again')),
              )
            else if (list.isEmpty)
              _Message(
                icon: _onHistory ? Icons.history : Icons.local_shipping_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                text: _search != null
                    ? 'No vehicle matches "$_search".'
                    : _onHistory
                        ? 'No history yet.'
                        : 'No vehicle is waiting outside the gate.',
              )
            else ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: r.isWaiting
                      ? _WaitingCard(
                          report: r,
                          onGateEntry: canAct ? () => _makeGateEntry(r) : null,
                          onRemove: canAct ? () => _remove(r) : null,
                        )
                      : _HistoryCard(report: r),
                ),
              if (_onHistory && _historyPage < _historyPages)
                Center(
                  child: TextButton.icon(
                    onPressed: _loadingMore ? null : _loadMoreHistory,
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more_rounded),
                    label: const Text('Show more'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _waitColor(int minutes) => minutes >= 120
    ? const Color(0xFFD32F2F)
    : minutes >= 60
        ? Colors.orange.shade800
        : Colors.green.shade700;

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.report, this.onGateEntry, this.onRemove});

  final VehicleReport report;
  final VoidCallback? onGateEntry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final wait = _waitColor(r.waitedMinutes);
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.vehicleNo,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
              _Chip(label: 'Waiting ${r.waitedLabel}', color: wait),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reported at ${r.reportedAt == null ? '—' : _time.format(r.reportedAt!)}'
            '${r.reportedAt == null ? '' : ' · ${DateFormat('dd MMM').format(r.reportedAt!)}'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Fact(
                icon: Icons.store_outlined,
                text: r.vendorName ?? 'Vendor not given',
              ),
              _Fact(icon: Icons.person_outline, text: r.driverName ?? 'Driver'),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: r.driverContactNo.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse('tel:${r.driverContactNo}')),
                child: _Fact(
                  icon: Icons.phone_outlined,
                  text: r.driverContactNo,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (onGateEntry != null || onRemove != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onRemove != null)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Remove'),
                  ),
                const Spacer(),
                if (onGateEntry != null)
                  FilledButton.icon(
                    onPressed: onGateEntry,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Gate Entry'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.report});

  final VehicleReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final (label, color) = switch (r.status) {
      'entered' => ('Entered', Colors.green.shade700),
      'removed' => ('Removed', Colors.grey.shade700),
      'expired' => ('Expired', Colors.orange.shade800),
      _ => (r.status, Colors.grey.shade700),
    };
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return VistarCard(
      padding: const EdgeInsets.all(16),
      onTap: (r.countSheetNo ?? '').isEmpty
          ? null
          : () => openCountSheet(context, r.countSheetNo!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.vehicleNo,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
              _Chip(label: label, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reported ${_fmt(r.reportedAt)}  →  $label ${_fmt(r.closedAt)}'
            '  ·  waited ${r.waitedLabel}',
            style: muted,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (r.vendorName != null) _Fact(icon: Icons.store_outlined, text: r.vendorName!),
              _Fact(
                icon: Icons.person_outline,
                text: [r.driverName, r.driverContactNo]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
              ),
              if (r.gateEntryNo != null)
                _Fact(icon: Icons.receipt_long_outlined, text: r.gateEntryNo!),
              if (r.countSheetNo != null)
                _Fact(
                  icon: Icons.fact_check_outlined,
                  text: 'Count Sheet ${r.countSheetNo}',
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
          if (r.closeReason != null || r.closedBy != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (r.closeReason != null) r.closeReason!,
                if (r.closedBy != null) 'by ${r.closedBy}',
              ].join(' · '),
              style: muted,
            ),
          ],
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: c))),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.color, required this.text, this.action});

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
