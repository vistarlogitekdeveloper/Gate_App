import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/vtt_repository.dart';
import '../domain/vtt_models.dart';
import 'trip_detail_page.dart';
import 'vtt_setup_page.dart';
import 'vtt_widgets.dart';

/// Vehicle tracking: the live board (where every vehicle is, one tap to
/// record the next checkpoint) and the trips list.
class VehicleTrackingPage extends ConsumerStatefulWidget {
  const VehicleTrackingPage({super.key});

  @override
  ConsumerState<VehicleTrackingPage> createState() => _VehicleTrackingPageState();
}

class _VehicleTrackingPageState extends ConsumerState<VehicleTrackingPage> with SingleTickerProviderStateMixin {
  static const _pageSize = 25;
  static const _statuses = <String?, String>{null: 'All', 'open': 'Running', 'completed': 'Completed', 'cancelled': 'Cancelled'};

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  Timer? _autoRefresh;
  Timer? _debounce;
  String _search = '';
  int _seq = 0;

  bool _loading = true;
  String? _error;
  VttBoard? _board;
  List<VttTrip> _trips = const [];
  String? _status;
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  bool _loadingMore = false;
  String? _busyKey;

  bool get _onTrips => _tabs.index == 1;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) _load();
      });
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_onTrips && _busyKey == null) _load(quiet: true);
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
    final trips = _onTrips;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(vttRepositoryProvider);
      if (trips) {
        final page = await repo.trips(status: _status, search: _search, page: 1, limit: _pageSize);
        if (!mounted || seq != _seq) return;
        setState(() {
          _trips = page.trips;
          _page = page.page;
          _pages = page.totalPages;
          _total = page.total;
        });
      } else {
        final board = await repo.board();
        if (!mounted || seq != _seq) return;
        setState(() => _board = board);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (!quiet) _error = vttError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(vttRepositoryProvider)
          .trips(status: _status, search: _search, page: _page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _trips = [..._trips, ...page.trips];
        _page = page.page;
        _pages = page.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      if (_onTrips) _load();
    });
  }

  Future<void> _record(VttBoardRow v, VttRecordable c) async {
    final remarkCtrl = TextEditingController();
    final auto = c.autoSource;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name}: ${v.vehicleNo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Records the time now.'),
            if (auto != null) ...[
              const SizedBox(height: 8),
              Text(
                'This is usually filled by the ${vttAutoSources[auto]?.toLowerCase() ?? 'Gate app'}. '
                'Record it here only if that was missed.',
                style: const TextStyle(color: vttRevisedColor),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Remark (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Record'),
          ),
        ],
      ),
    );
    final remark = remarkCtrl.text;
    remarkCtrl.dispose();
    if (go != true || !mounted) return;
    setState(() => _busyKey = '${v.vehicleId}/${c.id}');
    try {
      final trip = await ref.read(vttRepositoryProvider).record(vehicleId: v.vehicleId, checkpointId: c.id, remark: remark);
      if (!mounted) return;
      final at = trip.entries.isEmpty ? null : trip.entries.last.at;
      vttSnack(context,
          '${c.name} recorded for ${v.vehicleNo} at ${vttWhen(at)}${trip.status == 'completed' ? ' — trip completed' : ''}');
    } catch (e) {
      if (mounted) vttSnack(context, vttError(e), error: true);
    }
    if (mounted) setState(() => _busyKey = null);
    _load(quiet: true);
  }

  Future<void> _openTrip(String tripId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripDetailPage(tripId: tripId)));
    if (mounted) _load(quiet: true);
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VttSetupPage()));
    ref.invalidate(vttSettingsProvider);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final settingsAsync = ref.watch(vttSettingsProvider);
    final settings = settingsAsync.valueOrNull;
    final canManage = settings?.canManage ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            RibbonAccentBar(height: 22),
            SizedBox(width: 10),
            Flexible(child: Text('Vehicle Tracking')),
          ],
        ),
        actions: [
          if (canManage)
            mob
                ? IconButton(tooltip: 'Setup', icon: const Icon(Icons.tune_rounded), onPressed: _openSetup)
                : TextButton.icon(
                    onPressed: _openSetup,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Setup'),
                  ),
          if (settings?.enabled ?? false)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          const SizedBox(width: 8),
        ],
        bottom: (settings?.enabled ?? false)
            ? TabBar(controller: _tabs, tabs: const [Tab(text: 'Live'), Tab(text: 'Trips')])
            : null,
      ),
      body: settingsAsync.isLoading && settings == null
          ? const Center(child: CircularProgressIndicator())
          : settings == null || !settings.enabled
              ? _switchedOff(settings)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, mob ? 96 : 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: _onTrips ? _tripsTab() : _liveTab(),
                  ),
                ),
    );
  }

  Widget _switchedOff(VttSettings? s) {
    if (s?.canManage ?? false) {
      return VttMessage(
        icon: Icons.route_rounded,
        color: Theme.of(context).colorScheme.primary,
        text: 'Vehicle tracking is off for your organisation.\n'
            'Choose the checkpoints you want (Gate In / Out, Dock In / Out, or the full route), '
            'add your vehicles and switch it on.',
        action: FilledButton.icon(
          onPressed: _openSetup,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Set up vehicle tracking'),
        ),
      );
    }
    return const VttMessage(
      icon: Icons.route_outlined,
      text: 'Vehicle tracking is not switched on for your organisation. Ask your admin.',
    );
  }

  Widget _searchField(String hint) => TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                ),
        ),
      );

  List<Widget> _skeletons() => List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonLoader(width: double.infinity, height: 130),
        ),
      );

  List<Widget> _liveTab() {
    final board = _board;
    final key = _search.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final rows = (board?.vehicles ?? const <VttBoardRow>[])
        .where((v) => key.isEmpty || v.vehicleNo.contains(key))
        .toList();
    final onTrip = rows.where((v) => v.trip != null).length;
    return [
      SectionHeader(
        title: 'Live',
        subtitle: board == null
            ? 'Where every vehicle is on its trip.'
            : '$onTrip of ${board.vehicles.length} vehicle${board.vehicles.length == 1 ? '' : 's'} on a trip · '
                '${board.checkpoints.length} checkpoints. Tap Record when the vehicle reaches yours.',
      ),
      const SizedBox(height: 12),
      _searchField('Search vehicle number…'),
      const SizedBox(height: 16),
      if (_loading && board == null)
        ..._skeletons()
      else if (_error != null)
        VttMessage(
          icon: Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Try again')),
        )
      else if (board != null && board.vehicles.isEmpty)
        const VttMessage(
          icon: Icons.local_shipping_outlined,
          text: 'No vehicles yet. An admin adds them in Setup → Vehicles.',
        )
      else if (rows.isEmpty)
        VttMessage(icon: Icons.search_off, text: 'No vehicle matches "$_search".')
      else
        for (final v in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BoardCard(
              row: v,
              checkpoints: board!.checkpoints,
              busyKey: _busyKey,
              onRecord: (c) => _record(v, c),
              onOpen: v.trip == null ? null : () => _openTrip(v.trip!.id),
            ),
          ),
    ];
  }

  List<Widget> _tripsTab() {
    return [
      SectionHeader(
        title: 'Trips',
        subtitle: '$_total trip${_total == 1 ? '' : 's'}, newest first. Tap one for every time recorded.',
      ),
      const SizedBox(height: 12),
      _searchField('Search vehicle number…'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          for (final e in _statuses.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _status == e.key,
              onSelected: (_) {
                setState(() => _status = e.key);
                _load();
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (_loading && _trips.isEmpty)
        ..._skeletons()
      else if (_error != null)
        VttMessage(
          icon: Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Try again')),
        )
      else if (_trips.isEmpty)
        const VttMessage(icon: Icons.route_outlined, text: 'No trips yet.')
      else ...[
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        for (final t in _trips)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TripCard(trip: t, onOpen: () => _openTrip(t.id)),
          ),
        if (_page < _pages)
          Center(
            child: TextButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Show more'),
            ),
          ),
      ],
    ];
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.row,
    required this.checkpoints,
    required this.busyKey,
    required this.onRecord,
    this.onOpen,
  });

  final VttBoardRow row;
  final List<VttCheckpoint> checkpoints;
  final String? busyKey;
  final void Function(VttRecordable) onRecord;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = row;
    final trip = v.trip;
    final done = v.lastCheckpoint == null ? 0 : checkpoints.indexWhere((c) => c.name == v.lastCheckpoint) + 1;
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(trip == null ? Icons.local_shipping_outlined : Icons.local_shipping_rounded,
                    color: trip == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    v.vehicleNo,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                if (v.stale)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: VttChip(label: 'Open > 24h', color: Color(0xFFD32F2F), icon: Icons.warning_amber_rounded),
                  ),
                if (trip != null)
                  VttChip(
                    label: v.elapsedMinutes == null ? 'On trip' : durationLabel(v.elapsedMinutes),
                    color: vttStatusColor(context, v.status),
                    icon: Icons.timer_outlined,
                  )
                else
                  VttChip(label: 'Idle', color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            if (v.category != null || v.transporter != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text([v.category, v.transporter].whereType<String>().join(' · '), style: muted),
              ),
            const SizedBox(height: 12),
            if (trip != null) ...[
              VttProgressDots(total: checkpoints.length, done: done, status: v.status),
              const SizedBox(height: 10),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Last: ', style: muted),
                TextSpan(
                  text: '${v.lastCheckpoint ?? '—'} · ${vttWhen(v.lastAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ])),
              if (v.nextCheckpoint != null) ...[
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'Next: ', style: muted),
                      TextSpan(text: v.nextCheckpoint, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
                    VttStepTime(minutes: v.elapsedMinutes, target: v.targetMinutes, status: v.status, prefix: 'waiting '),
                  ],
                ),
              ],
            ] else
              Text(
                v.lastTripEndedAt == null ? 'Not on a trip.' : 'Not on a trip · last trip ended ${vttWhen(v.lastTripEndedAt)}',
                style: muted,
              ),
            if (v.canRecord.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, c) in v.canRecord.indexed)
                    _recordButton(c, i == 0, busyKey == '${v.vehicleId}/${c.id}', busyKey != null),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordButton(VttRecordable c, bool primary, bool busy, bool anyBusy) {
    final icon = busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.touch_app_rounded, size: 18);
    final label = Text('Record ${c.name}');
    final onPressed = anyBusy ? null : () => onRecord(c);
    return primary
        ? FilledButton.icon(onPressed: onPressed, icon: icon, label: label)
        : FilledButton.tonalIcon(onPressed: onPressed, icon: icon, label: label);
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onOpen});
  final VttTrip trip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final t = trip;
    final last = t.entries.isEmpty ? null : t.entries.last;
    final revised = t.entries.where((e) => e.revised).length;
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.vehicleNo,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                if (revised > 0)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: VttChip(label: 'Revised', color: vttRevisedColor, icon: Icons.edit_calendar_rounded),
                  ),
                VttChip(label: vttTripStatusLabel(t.status), color: vttTripStatusColor(t.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Started ${vttWhen(t.startedAt)}${t.endedAt == null ? '' : ' · ended ${vttWhen(t.endedAt)}'}',
              style: muted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VttStepTime(
                  minutes: t.totalMinutes,
                  target: t.totalTargetMinutes,
                  status: t.totalStatus,
                  prefix: t.isOpen ? 'So far ' : 'Total ',
                ),
                if (last != null)
                  Text('${t.entries.length} checkpoint${t.entries.length == 1 ? '' : 's'} · last ${last.checkpoint}',
                      style: muted),
                if (t.closeReason != null) Text('Reason: ${t.closeReason}', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
