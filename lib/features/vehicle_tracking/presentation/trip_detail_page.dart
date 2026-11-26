import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/vtt_repository.dart';
import '../domain/vtt_models.dart';
import 'vtt_widgets.dart';

/// Every time recorded on one trip, each step against its target; corrections
/// (orange, "Revised") and, for an admin, closing a stuck trip.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  VttTrip? _trip;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trip = await ref.read(vttRepositoryProvider).trip(widget.tripId);
      if (mounted) setState(() => _trip = trip);
    } catch (e) {
      if (mounted) setState(() => _error = vttError(e));
    }
  }

  Future<void> _revise(VttEntry e) async {
    final current = e.at ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: current.subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      helpText: 'Correct date for ${e.checkpoint}',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Correct time for ${e.checkpoint}',
    );
    if (time == null || !mounted) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final reason = await askReason(
      context,
      title: 'Correct ${e.checkpoint}',
      message: '${vttDateTime.format(current)}  →  ${vttDateTime.format(at)}\n'
          'The original time is kept and the new one shows as "Revised".',
      quick: const ['Tapped late', 'Tapped by mistake', 'Network was down'],
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final trip = await ref.read(vttRepositoryProvider).revise(e.id, at: at, reason: reason);
      if (!mounted) return;
      setState(() => _trip = trip);
      vttSnack(context, '${e.checkpoint} corrected to ${vttDateTime.format(at)}');
    } catch (err) {
      if (mounted) vttSnack(context, vttError(err), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _close(String action) async {
    final t = _trip!;
    final cancel = action == 'cancel';
    final reason = await askReason(
      context,
      title: cancel ? 'Cancel trip of ${t.vehicleNo}?' : 'Close trip of ${t.vehicleNo}?',
      message: cancel
          ? 'A cancelled trip is left out of reports. Use this for a trip that should not count.'
          : 'Marks the trip completed with the times recorded so far '
              '(${t.remaining.length} checkpoint${t.remaining.length == 1 ? '' : 's'} not recorded).',
      action: cancel ? 'Cancel trip' : 'Close trip',
      quick: cancel ? const ['Started by mistake', 'Test entry'] : const ['Checkpoint missed', 'Vehicle broke down'],
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final trip = await ref.read(vttRepositoryProvider).closeTrip(t.id, action: action, reason: reason);
      if (!mounted) return;
      setState(() => _trip = trip);
      vttSnack(context, cancel ? 'Trip cancelled' : 'Trip closed');
    } catch (err) {
      if (mounted) vttSnack(context, vttError(err), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _showOriginal(VttEntry e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${e.checkpoint}: revised'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Time now', vttDateTime.format(e.at!)),
            _kv('Originally recorded', e.recordedAt == null ? '—' : vttDateTime.format(e.recordedAt!)),
            _kv('Recorded by', e.recordedBy ?? '—'),
            _kv('Corrected by', e.revisedBy ?? '—'),
            _kv('Corrected on', e.revisedOn == null ? '—' : vttDateTime.format(e.revisedOn!)),
            _kv('Reason', e.revisionReason ?? '—'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final session = ref.watch(sessionControllerProvider);
    final isAdmin = session is Authenticated && session.role == UserRole.admin;
    final t = _trip;
    return Scaffold(
      appBar: AppBar(
        title: Text(t == null ? 'Trip' : 'Trip: ${t.vehicleNo}'),
        actions: [
          if (t != null && t.isOpen && isAdmin)
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: _close,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'complete', child: Text('Close trip (mark completed)')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel trip')),
              ],
            ),
        ],
      ),
      body: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : VttMessage(icon: Icons.error_outline, text: _error!, color: Theme.of(context).colorScheme.error),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, 32),
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                _summary(t),
                const SizedBox(height: 16),
                for (final (i, e) in t.entries.indexed) _entryTile(e, first: i == 0),
                for (final name in t.remaining) _pendingTile(name),
              ],
            ),
    );
  }

  Widget _summary(VttTrip t) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.vehicleNo,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              VttChip(label: vttTripStatusLabel(t.status), color: vttTripStatusColor(t.status)),
            ],
          ),
          if (t.category != null) Text(t.category!, style: muted),
          const SizedBox(height: 8),
          Text('Started ${vttDateTime.format(t.startedAt ?? DateTime.now())}'
              '${t.endedAt == null ? '' : '  ·  Ended ${vttDateTime.format(t.endedAt!)}'}'),
          const SizedBox(height: 4),
          VttStepTime(
            minutes: t.totalMinutes,
            target: t.totalTargetMinutes,
            status: t.totalStatus,
            prefix: t.isOpen ? 'So far ' : 'Total trip time ',
          ),
          if (t.closeReason != null) ...[
            const SizedBox(height: 6),
            Text('${t.status == 'cancelled' ? 'Cancelled' : 'Closed'} by ${t.closedBy ?? 'admin'}: ${t.closeReason}',
                style: muted),
          ],
        ],
      ),
    );
  }

  Widget _entryTile(VttEntry e, {required bool first}) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final timeColor = e.revised ? vttRevisedColor : theme.colorScheme.onSurface;
    final details = [
      if (e.recordedBy != null) 'by ${e.recordedBy}',
      if (e.source != 'tap') vttSourceLabel(e.source),
      if (e.gateEntryNo != null) e.gateEntryNo!,
      if (e.countSheetNo != null) 'count sheet ${e.countSheetNo}',
    ].join(' · ');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 10, color: first ? Colors.transparent : theme.colorScheme.primary),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary),
                ),
                Expanded(child: Container(width: 2, color: theme.colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.checkpoint + (e.site == null || e.checkpoint.contains(e.site!) ? '' : ' (${e.site})'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (e.canRevise)
                        TextButton.icon(
                          onPressed: _busy ? null : () => _revise(e),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: const Text('Revise'),
                        ),
                    ],
                  ),
                  InkWell(
                    onTap: e.revised ? () => _showOriginal(e) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.at == null ? '—' : vttDateTime.format(e.at!),
                          style: TextStyle(color: timeColor, fontWeight: FontWeight.w700),
                        ),
                        if (e.revised) ...[
                          const SizedBox(width: 6),
                          const VttChip(label: 'Revised', color: vttRevisedColor),
                        ],
                      ],
                    ),
                  ),
                  if (details.isNotEmpty) Text(details, style: muted),
                  if (e.segmentMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: VttStepTime(
                        minutes: e.segmentMinutes,
                        target: e.targetMinutes,
                        status: e.status,
                        prefix: 'Step ',
                      ),
                    ),
                  if (e.remark != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('“${e.remark}”', style: muted?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingTile(String name) {
    final theme = Theme.of(context);
    final off = theme.colorScheme.outlineVariant;
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: off, width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(name, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
