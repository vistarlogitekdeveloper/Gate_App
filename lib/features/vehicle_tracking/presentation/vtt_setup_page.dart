import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/vtt_repository.dart';
import '../domain/vtt_models.dart';
import 'vtt_widgets.dart';

/// Admin: which checkpoints this organisation uses (ready-made sets or its
/// own), who records each, target times, the vehicles, and the main switch.
class VttSetupPage extends ConsumerStatefulWidget {
  const VttSetupPage({super.key});

  @override
  ConsumerState<VttSetupPage> createState() => _VttSetupPageState();
}

class _VttSetupPageState extends ConsumerState<VttSetupPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  VttSettings? _settings;
  List<VttCheckpoint> _checkpoints = const [];
  List<VttCategory> _categories = const [];
  List<VttVehicle> _vehicles = const [];
  List<VttUser> _users = const [];

  final _windowCtrl = TextEditingController();
  final _amberCtrl = TextEditingController();

  VttRepository get _repo => ref.read(vttRepositoryProvider);
  List<VttCheckpoint> get _active => _checkpoints.where((c) => c.isActive).toList();
  List<VttCheckpoint> get _inactive => _checkpoints.where((c) => !c.isActive).toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _windowCtrl.dispose();
    _amberCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.settings(),
        _repo.checkpoints(),
        _repo.categories(),
        _repo.vehicles(),
        _repo.users(),
      ]);
      if (!mounted) return;
      setState(() {
        _settings = results[0] as VttSettings;
        _checkpoints = results[1] as List<VttCheckpoint>;
        _categories = results[2] as List<VttCategory>;
        _vehicles = results[3] as List<VttVehicle>;
        _users = results[4] as List<VttUser>;
        _windowCtrl.text = '${_settings!.reviseWindowHours}';
        _amberCtrl.text = '${_settings!.amberPercent}';
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = vttError(e);
        });
      }
    }
  }

  /// Run a change, then reload; errors as a red message.
  Future<bool> _do(Future<void> Function() fn, {String? done}) async {
    setState(() => _busy = true);
    var ok = false;
    try {
      await fn();
      ok = true;
      if (mounted && done != null) vttSnack(context, done);
    } catch (e) {
      if (mounted) vttSnack(context, vttError(e), error: true);
    }
    await _load();
    if (mounted) setState(() => _busy = false);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _settings?.enabled ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Tracking Setup'),
        actions: [
          if (_settings != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: VttChip(
                label: enabled ? 'On' : 'Off',
                color: enabled ? const Color(0xFF2E7D32) : const Color(0xFF757575),
                icon: enabled ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Checkpoints (${_active.length})'),
            Tab(text: 'Vehicles (${_vehicles.where((v) => v.isActive).length})'),
            const Tab(text: 'Switch & rules'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? VttMessage(
                  icon: Icons.error_outline,
                  text: _error!,
                  color: Theme.of(context).colorScheme.error,
                  action: TextButton(onPressed: _load, child: const Text('Try again')),
                )
              : Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [_checkpointsTab(), _vehiclesTab(), _settingsTab()],
                      ),
                    ),
                  ],
                ),
    );
  }

  EdgeInsets get _pad {
    final mob = isMobile(context);
    return EdgeInsets.fromLTRB(mob ? 12 : 24, 16, mob ? 12 : 24, 32);
  }

  // ── checkpoints ──────────────────────────────────────────────────────────

  Widget _checkpointsTab() {
    final theme = Theme.of(context);
    final active = _active;
    return ReorderableListView.builder(
      padding: _pad,
      buildDefaultDragHandles: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A trip starts at the first checkpoint and ends at the last. Change the order with the ↑ ↓ arrows '
            'or by dragging ⠿ (⋮ also has Move to first / last). '
            'Mandatory checkpoints must be recorded before any after them; optional ones may be passed by.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _chooseTemplate,
                icon: const Icon(Icons.auto_awesome_motion_rounded),
                label: const Text('Use a ready-made set'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editCheckpoint(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add checkpoint'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (active.isEmpty)
            const VttMessage(
              icon: Icons.flag_outlined,
              text: 'No checkpoints yet. Start with a ready-made set: Gate In → Gate Out, Dock In → Dock Out, '
                  'or the full pick-up → delivery route.',
            ),
        ],
      ),
      footer: _inactive.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text('Switched off (kept for past trips)', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final c in _inactive)
                  Card(
                    child: ListTile(
                      enabled: false,
                      title: Text(c.name),
                      subtitle: Text(_checkpointSubtitle(c)),
                      trailing: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _do(() => _repo.updateCheckpoint(c.id, isActive: true), done: '${c.name} switched on'),
                        child: const Text('Switch on'),
                      ),
                    ),
                  ),
              ],
            ),
      itemCount: active.length,
      onReorderItem: _move,
      itemBuilder: (context, i) {
        final c = active[i];
        final last = i == active.length - 1;
        return Card(
          key: ValueKey(c.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Text('${i + 1}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_checkpointSubtitle(c, first: i == 0, last: last && active.length > 1)),
            isThreeLine: true,
            onTap: () => _editCheckpoint(c),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: _busy || i == 0 ? null : () => _move(i, i - 1),
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward_rounded),
                  onPressed: _busy || last ? null : () => _move(i, i + 1),
                ),
                ReorderableDragStartListener(
                  index: i,
                  enabled: !_busy,
                  child: const Tooltip(
                    message: 'Drag to move',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_busy,
                  onSelected: (v) => switch (v) {
                    'edit' => _editCheckpoint(c),
                    'users' => _editUsers(c),
                    'targets' => _editTargets(c, first: i == 0),
                    'top' => _move(i, 0),
                    'bottom' => _move(i, active.length - 1),
                    'remove' => _removeCheckpoint(c),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'users', child: Text('Who records it')),
                    if (i > 0) const PopupMenuItem(value: 'targets', child: Text('Target time')),
                    if (i > 0) const PopupMenuItem(value: 'top', child: Text('Move to first (starts the trip)')),
                    if (!last) const PopupMenuItem(value: 'bottom', child: Text('Move to last (ends the trip)')),
                    PopupMenuItem(value: 'remove', child: Text(c.used ? 'Switch off' : 'Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Move the active checkpoint at [from] to position [to] and save the order.
  void _move(int from, int to) {
    final list = [..._active];
    if (from == to || from < 0 || from >= list.length || to < 0 || to >= list.length) return;
    final moved = list.removeAt(from);
    list.insert(to, moved);
    setState(() => _checkpoints = [...list, ..._inactive]);
    _do(() => _repo.reorderCheckpoints(list.map((c) => c.id).toList()),
        done: '${moved.name} is now number ${to + 1}');
  }

  String _checkpointSubtitle(VttCheckpoint c, {bool first = false, bool last = false}) {
    final target = c.defaultTarget;
    final own = c.targets.where((t) => t.categoryId != null).length;
    return [
      [
        if (c.site != null) c.site!,
        vttKinds[c.kind] ?? c.kind,
        c.isMandatory ? 'Mandatory' : 'Optional',
        if (first) 'Starts the trip',
        if (last) 'Ends the trip',
      ].join(' · '),
      [
        c.autoSource == null ? 'Recorded by a tap' : 'Filled by ${vttAutoSources[c.autoSource]?.toLowerCase()}',
        c.users.isEmpty ? 'anyone may record' : '${c.users.length} assigned',
        if (!first) target == null ? 'no target' : 'target ${durationLabel(target)}${own > 0 ? ' (+$own by category)' : ''}',
      ].join(' · '),
    ].join('\n');
  }

  Future<void> _chooseTemplate() async {
    List<VttTemplate> sets;
    try {
      sets = await _repo.templates();
    } catch (e) {
      if (mounted) vttSnack(context, vttError(e), error: true);
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<VttTemplate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose the checkpoints'),
        children: [
          for (final s in sets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(s.description, style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    String? from;
    String? to;
    if (chosen.needsSites) {
      final fromCtrl = TextEditingController();
      final toCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Name the two sites'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Pick-up site (e.g. Cytiva)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toCtrl,
                decoration: const InputDecoration(labelText: 'Delivery site (e.g. KB)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Next')),
          ],
        ),
      );
      from = fromCtrl.text.trim();
      to = toCtrl.text.trim();
      fromCtrl.dispose();
      toCtrl.dispose();
      if (ok != true || !mounted) return;
    }
    final replace = _active.isNotEmpty;
    final preview = chosen.checkpoints
        .map((n) => n.replaceAll('{from}', from?.isNotEmpty == true ? from! : 'Pick-up').replaceAll(
            '{to}', to?.isNotEmpty == true ? to! : 'Delivery'))
        .toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(chosen.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, n) in preview.indexed) Text('${i + 1}. $n'),
            if (replace) ...[
              const SizedBox(height: 12),
              Text(
                'This replaces your ${_active.length} current checkpoints. Ones already on trips are switched off '
                '(kept for those trips); the rest are deleted.',
                style: const TextStyle(color: vttRevisedColor),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(replace ? 'Replace' : 'Use these')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _do(() => _repo.applyTemplate(chosen.key, replace: replace, from: from, to: to),
        done: 'Checkpoints set up');
  }

  Future<void> _editCheckpoint(VttCheckpoint? c) async {
    final nameCtrl = TextEditingController(text: c?.name ?? '');
    final siteCtrl = TextEditingController(text: c?.site ?? '');
    var kind = c?.kind ?? 'custom';
    var mandatory = c?.isMandatory ?? true;
    String? auto = c?.autoSource;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(c == null ? 'Add checkpoint' : 'Edit ${c.name}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: c == null,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: [for (final e in vttKinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setLocal(() => kind = v ?? 'custom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: siteCtrl,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Site (optional, e.g. Cytiva)', border: OutlineInputBorder()),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: auto,
                    decoration: const InputDecoration(labelText: 'Recorded by', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('A tap in this screen')),
                      for (final e in vttAutoSources.entries)
                        DropdownMenuItem<String?>(value: e.key, child: Text('Automatically: ${e.value.toLowerCase()}')),
                    ],
                    onChanged: (v) => setLocal(() => auto = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: mandatory,
                    onChanged: (v) => setLocal(() => mandatory = v),
                    title: const Text('Mandatory'),
                    subtitle: const Text('Off: this checkpoint may be passed by'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final site = siteCtrl.text.trim();
    nameCtrl.dispose();
    siteCtrl.dispose();
    if (ok != true || !mounted) return;
    if (c == null) {
      await _do(
          () => _repo.createCheckpoint(name: name, kind: kind, site: site, isMandatory: mandatory, autoSource: auto),
          done: '$name added');
    } else {
      await _do(
          () => _repo.updateCheckpoint(c.id,
              name: name, kind: kind, site: site, isMandatory: mandatory, autoSource: auto, setAutoSource: true),
          done: '$name saved');
    }
  }

  Future<void> _editUsers(VttCheckpoint c) async {
    final picked = c.users.map((u) => u.id).toSet();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Who records "${c.name}"'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nobody ticked: anyone who records checkpoints may record it. Admins always can.'),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in _users)
                        CheckboxListTile(
                          dense: true,
                          value: picked.contains(u.id),
                          title: Text(u.name),
                          subtitle: Text(u.role.replaceAll('_', ' ')),
                          onChanged: (v) => setLocal(() => v == true ? picked.add(u.id) : picked.remove(u.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _do(() => _repo.setCheckpointUsers(c.id, picked.toList()), done: 'Saved who records ${c.name}');
  }

  Future<void> _editTargets(VttCheckpoint c, {required bool first}) async {
    final rows = <String?, TextEditingController>{
      null: TextEditingController(text: c.defaultTarget?.toString() ?? ''),
      for (final k in _categories.where((k) => k.isActive))
        k.id: TextEditingController(text: c.targetFor(k.id)?.toString() ?? ''),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Target time: ${c.name}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minutes from the checkpoint before this one. Empty = no target.\n'
                    'A new target counts from now; past trips keep theirs.'),
                const SizedBox(height: 12),
                for (final e in rows.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: e.key == null
                            ? 'All vehicles (minutes)'
                            : '${_categories.firstWhere((k) => k.id == e.key).name} (minutes)',
                        hintText: e.key == null ? null : 'Same as all vehicles',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final values = {for (final e in rows.entries) e.key: int.tryParse(e.value.text.trim())};
    for (final ctrl in rows.values) {
      ctrl.dispose();
    }
    if (ok != true || !mounted) return;
    await _do(() => _repo.setTargets(c.id, values), done: 'Targets saved for ${c.name}');
  }

  Future<void> _removeCheckpoint(VttCheckpoint c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.used ? 'Switch off ${c.name}?' : 'Delete ${c.name}?'),
        content: Text(c.used
            ? 'It is on past trips, so it is kept for them, but no longer recorded.'
            : 'It has never been recorded, so it is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(c.used ? 'Switch off' : 'Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _do(() async => _repo.deleteCheckpoint(c.id), done: c.used ? '${c.name} switched off' : '${c.name} deleted');
  }

  // ── vehicles ─────────────────────────────────────────────────────────────

  Widget _vehiclesTab() {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return ListView(
      padding: _pad,
      children: [
        Text('Vehicle categories', style: theme.textTheme.titleSmall),
        Text('Vehicles of one category share target times (e.g. by size).', style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in _categories)
              InputChip(
                label: Text(k.name),
                isEnabled: k.isActive,
                onPressed: _busy ? null : () => _editCategory(k),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add category'),
              onPressed: _busy ? null : () => _editCategory(null),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Vehicles', style: theme.textTheme.titleSmall)),
            FilledButton.icon(
              onPressed: _busy ? null : () => _editVehicle(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add vehicle'),
            ),
          ],
        ),
        Text('Only these vehicles are tracked. The number must match the one used in gate entries.', style: muted),
        const SizedBox(height: 8),
        if (_vehicles.isEmpty)
          const VttMessage(icon: Icons.local_shipping_outlined, text: 'No vehicles yet.')
        else
          for (final v in _vehicles)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.local_shipping_rounded,
                    color: v.isActive ? theme.colorScheme.primary : theme.colorScheme.outline),
                title: Text(v.vehicleNo,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: v.isActive ? null : theme.colorScheme.outline)),
                subtitle: Text([
                  v.category ?? 'No category',
                  if (v.transporter != null) v.transporter!,
                  if (v.capacity != null) v.capacity!,
                  if (v.hoursPerDay != null) '${v.hoursPerDay} h/day',
                  if (!v.isActive) 'switched off',
                ].join(' · ')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy ? null : () => _editVehicle(v),
              ),
            ),
      ],
    );
  }

  Future<void> _editCategory(VttCategory? k) async {
    final nameCtrl = TextEditingController(text: k?.name ?? '');
    final descCtrl = TextEditingController(text: k?.description ?? '');
    var active = k?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(k == null ? 'Add category' : 'Edit ${k.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: k == null,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Name * (e.g. Truck 10T)', border: OutlineInputBorder()),
              ),
              TextField(
                controller: descCtrl,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              if (k != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('In use'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    nameCtrl.dispose();
    descCtrl.dispose();
    if (ok != true || !mounted) return;
    await _do(() => _repo.saveCategory(id: k?.id, name: name, description: desc, isActive: k == null ? null : active),
        done: 'Category saved');
  }

  Future<void> _editVehicle(VttVehicle? v) async {
    final noCtrl = TextEditingController(text: v?.vehicleNo ?? '');
    final transporterCtrl = TextEditingController(text: v?.transporter ?? '');
    final capacityCtrl = TextEditingController(text: v?.capacity ?? '');
    final hoursCtrl = TextEditingController(text: v?.hoursPerDay?.toString() ?? '');
    String? category = v?.categoryId;
    var active = v?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(v == null ? 'Add vehicle' : 'Edit ${v.vehicleNo}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: noCtrl,
                    autofocus: v == null,
                    maxLength: 10,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      TextInputFormatter.withFunction((_, n) => n.copyWith(text: n.text.toUpperCase())),
                    ],
                    decoration: const InputDecoration(labelText: 'Vehicle number * (e.g. MH12AB1234)', border: OutlineInputBorder()),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _categories.any((k) => k.id == category) ? category : null,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      for (final k in _categories.where((k) => k.isActive || k.id == category))
                        DropdownMenuItem<String?>(value: k.id, child: Text(k.name)),
                    ],
                    onChanged: (x) => setLocal(() => category = x),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: transporterCtrl,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Owner / transporter', border: OutlineInputBorder()),
                  ),
                  TextField(
                    controller: capacityCtrl,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Capacity (e.g. 10 T)', border: OutlineInputBorder()),
                  ),
                  TextField(
                    controller: hoursCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Hours available a day', hintText: 'e.g. 8', border: OutlineInputBorder()),
                  ),
                  if (v != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (x) => setLocal(() => active = x),
                      title: const Text('Tracked'),
                      subtitle: const Text('Off: hidden from the live board, kept in past trips'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (noCtrl.text.trim().length >= 4) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final no = noCtrl.text.trim();
    final transporter = transporterCtrl.text.trim();
    final capacity = capacityCtrl.text.trim();
    final hours = double.tryParse(hoursCtrl.text.trim());
    for (final c in [noCtrl, transporterCtrl, capacityCtrl, hoursCtrl]) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    await _do(
        () => _repo.saveVehicle(
              id: v?.id,
              vehicleNo: no,
              categoryId: category,
              transporter: transporter,
              capacity: capacity,
              hoursPerDay: hours,
              isActive: v == null ? null : active,
            ),
        done: '$no saved');
  }

  // ── switch and rules ─────────────────────────────────────────────────────

  Widget _settingsTab() {
    final s = _settings!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return ListView(
      padding: _pad,
      children: [
        VistarCard(
          padding: const EdgeInsets.all(8),
          child: SwitchListTile(
            value: s.enabled,
            onChanged: _busy
                ? null
                : (on) => _do(() => _repo.saveSettings(enabled: on),
                    done: on ? 'Vehicle tracking is on' : 'Vehicle tracking is off'),
            title: const Text('Vehicle tracking', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.enabled
                ? 'On: staff see the Trips screen and the Gate app fills the automatic checkpoints.'
                : 'Off: hidden from everyone; nothing is recorded. Needs at least two checkpoints to switch on.'),
          ),
        ),
        const SizedBox(height: 16),
        VistarCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rules', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: _windowCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Correction window (hours)',
                  helperText: 'The person who recorded a time may correct it for this long; after that only an admin.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amber margin (%)',
                  helperText: 'Live board: green within target, amber up to this much over, red beyond.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final w = int.tryParse(_windowCtrl.text.trim());
                          final a = int.tryParse(_amberCtrl.text.trim());
                          if (w == null || a == null) {
                            vttSnack(context, 'Enter whole numbers.', error: true);
                            return;
                          }
                          _do(() => _repo.saveSettings(reviseWindowHours: w, amberPercent: a), done: 'Rules saved');
                        },
                  child: const Text('Save rules'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Every change here is kept in the audit log.', style: muted),
      ],
    );
  }
}
