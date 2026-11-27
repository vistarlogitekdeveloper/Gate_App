import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';
import 'dispatch_page.dart';
import 'stock_sheet_page.dart';
import 'stock_reports_page.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import 'stock_widgets.dart';

/// Stock: count sheets with what was received, dispatched and is left. Tick
/// lines (from one or several count sheets) and Dispatch them on one vehicle.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool _open = true;
  bool _loading = true;
  String? _error;
  List<StockSheet> _sheets = const [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  bool _loadingMore = false;
  int _seq = 0;
  final Map<String, StockLine> _picked = {};

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
    final settings = await ref.read(stockSettingsProvider.future);
    if (settings == null || !settings.enabled) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ref.read(stockRepositoryProvider).list(open: _open, search: _search, page: 1, limit: _pageSize);
      if (!mounted || seq != _seq) return;
      setState(() {
        _sheets = p.sheets;
        _page = p.page;
        _pages = p.totalPages;
        _total = p.total;
        _loading = false;
        // Keep ticks only on lines still listed, at their new balance.
        final lines = {for (final s in p.sheets) for (final l in s.lines) l.key: l};
        _picked.removeWhere((k, _) => !lines.containsKey(k) || lines[k]!.balance <= 0);
        for (final k in _picked.keys.toList()) {
          _picked[k] = lines[k]!;
        }
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final p = await ref.read(stockRepositoryProvider).list(open: _open, search: _search, page: _page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _sheets = [..._sheets, ...p.sheets];
        _page = p.page;
        _pages = p.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search = v.trim();
      _load();
    });
  }

  Future<void> _setEnabled(bool on) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(on ? 'Switch on Stock & dispatch?' : 'Switch off Stock & dispatch?'),
        content: Text(on
            ? 'Count sheets show what was received, dispatched and is left, and warehouse staff can dispatch '
                'stock against them. Nothing else changes.'
            : 'The Stock screen is hidden. Dispatches already made stay, and still protect their count sheets '
                '(an invoice cannot be edited below what was dispatched from it).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(on ? 'Switch on' : 'Switch off')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(stockRepositoryProvider).setEnabled(on);
      ref.invalidate(stockSettingsProvider);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  Future<void> _dispatch(List<StockLine> lines) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DispatchPage(lines: lines)));
    if (done == true) {
      setState(_picked.clear);
      _load();
    }
  }

  Future<void> _openSheet(String no) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockSheetPage(countSheetNo: no)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final settingsAsync = ref.watch(stockSettingsProvider);
    final settings = settingsAsync.valueOrNull;
    final enabled = settings?.enabled ?? false;
    final canDispatch = settings?.canDispatch ?? false;
    final picked = _picked.values.toList();
    final pickedQty = picked.fold<double>(0, (s, l) => s + l.balance);
    final session = ref.watch(sessionControllerProvider);
    final canReport = session is Authenticated && session.role.isAdminOrWarehouseManager;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(children: [RibbonAccentBar(height: 22), SizedBox(width: 10), Flexible(child: Text('Stock'))]),
        actions: [
          if (settings?.canManage ?? false)
            PopupMenuButton<String>(
              tooltip: 'Settings',
              icon: const Icon(Icons.tune_rounded),
              onSelected: (_) => _setEnabled(!enabled),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text(enabled ? 'Switch off Stock & dispatch' : 'Switch on Stock & dispatch')),
              ],
            ),
          if (enabled && canReport)
            IconButton(
              tooltip: 'Stock reports',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockReportsPage())),
            ),
          if (enabled)
            IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: canDispatch && picked.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, mob ? 88 : 12),
                child: FilledButton.icon(
                  onPressed: () => _dispatch(picked),
                  icon: const Icon(Icons.outbox_rounded),
                  label: Text('Dispatch ${picked.length} item${picked.length == 1 ? '' : 's'} (up to ${qtyLabel(pickedQty)})'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
            )
          : null,
      body: settingsAsync.isLoading && settings == null
          ? const Center(child: CircularProgressIndicator())
          : !enabled
              ? (settings?.canManage ?? false)
                  ? StockMessage(
                      icon: Icons.inventory_2_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      text: 'Stock & dispatch is off for your organisation.\n'
                          'Switched on, each count sheet shows Received · Dispatched · Balance, and warehouse staff '
                          'dispatch stock against it (e.g. received 100, dispatch 60, 40 left). Nothing else changes.',
                      action: FilledButton.icon(
                        onPressed: () => _setEnabled(true),
                        icon: const Icon(Icons.toggle_on_outlined),
                        label: const Text('Switch on'),
                      ),
                    )
                  : const StockMessage(
                      icon: Icons.inventory_2_outlined,
                      text: 'Stock & dispatch is not switched on for your organisation. Ask your admin.',
                    )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, mob ? 96 : 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SectionHeader(
                        title: 'Stock',
                        subtitle: '$_total count sheet${_total == 1 ? '' : 's'}${_open ? ' with stock left' : ''}. '
                            '${canDispatch ? 'Tick items and tap Dispatch.' : 'Tap a count sheet for its dispatches.'}',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearch,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search count sheet, invoice, vendor, vehicle, PO, material…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        ChoiceChip(
                          label: const Text('With stock left'),
                          selected: _open,
                          onSelected: (_) {
                            setState(() => _open = true);
                            _load();
                          },
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: !_open,
                          onSelected: (_) {
                            setState(() => _open = false);
                            _load();
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),
                      if (_loading && _sheets.isEmpty)
                        ...List.generate(
                          3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SkeletonLoader(width: double.infinity, height: 140),
                          ),
                        )
                      else if (_error != null)
                        StockMessage(
                          icon: Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          text: _error!,
                          action: TextButton(onPressed: _load, child: const Text('Try again')),
                        )
                      else if (_sheets.isEmpty)
                        StockMessage(
                          icon: Icons.inventory_2_outlined,
                          text: _search.isNotEmpty
                              ? 'No count sheet matches "$_search".'
                              : _open
                                  ? 'No stock left on any count sheet.'
                                  : 'No count sheets with items yet.',
                        )
                      else ...[
                        if (_loading) const LinearProgressIndicator(minHeight: 2),
                        for (final s in _sheets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SheetCard(
                              sheet: s,
                              canDispatch: canDispatch,
                              picked: _picked,
                              onToggle: (l, on) => setState(() => on ? _picked[l.key] = l : _picked.remove(l.key)),
                              onOpen: () => _openSheet(s.countSheetNo),
                            ),
                          ),
                        if (_page < _pages)
                          Center(
                            child: TextButton.icon(
                              onPressed: _loadingMore ? null : _loadMore,
                              icon: const Icon(Icons.expand_more_rounded),
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

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.sheet,
    required this.canDispatch,
    required this.picked,
    required this.onToggle,
    required this.onOpen,
  });

  final StockSheet sheet;
  final bool canDispatch;
  final Map<String, StockLine> picked;
  final void Function(StockLine, bool) onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final s = sheet;
    return VistarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Count Sheet ${s.countSheetNo}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (s.dispatchCount > 0)
                    Text('${s.dispatchCount} dispatch${s.dispatchCount == 1 ? '' : 'es'}', style: muted),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          Text(
            [
              if (s.vehicleNo != null) s.vehicleNo!,
              ...s.vendors,
              if (s.receivedAt != null) stockDateTime.format(s.receivedAt!),
            ].join(' · '),
            style: muted,
          ),
          const SizedBox(height: 6),
          StockTotalsRow(received: s.received, dispatched: s.dispatched, balance: s.balance),
          const Divider(height: 18),
          for (final l in s.lines)
            Row(
              children: [
                if (canDispatch)
                  Checkbox(
                    value: picked.containsKey(l.key),
                    onChanged: l.balance > 0 ? (v) => onToggle(l, v == true) : null,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: canDispatch ? 0 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l.title}  ·  Inv ${l.invoiceNo}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        StockTotalsRow(received: l.received, dispatched: l.dispatched, balance: l.balance, dense: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
