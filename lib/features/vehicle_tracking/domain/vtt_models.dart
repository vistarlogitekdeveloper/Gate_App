// Vehicle tracking: trip times through the checkpoints each organisation's
// admin chooses (server: /vehicle-tracking).

String _s(Object? v) => v == null ? '' : v.toString();
String? _sn(Object? v) {
  final s = _s(v).trim();
  return s.isEmpty ? null : s;
}

int? _i(Object? v) => v is num ? v.toInt() : int.tryParse(_s(v));
bool _b(Object? v) => v == true;
DateTime? _d(Object? v) {
  final s = _sn(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// "35m", "1h 05m", "2d 03h".
String durationLabel(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h < 24) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${h ~/ 24}d ${(h % 24).toString().padLeft(2, '0')}h';
}

/// Checkpoint types (the server's list) and how they read.
const vttKinds = <String, String>{
  'reported': 'Reported at gate',
  'gate_in': 'Gate In',
  'dock_in': 'Dock In',
  'loading_done': 'Loading done',
  'docs_ready': 'Documents ready',
  'dock_out': 'Dock Out',
  'unloading_done': 'Unloading done',
  'gate_out': 'Gate Out',
  'custom': 'Other',
};

/// What can fill a checkpoint without a tap.
const vttAutoSources = <String, String>{
  'vehicle_report': "Driver's QR report",
  'gate_entry_in': 'Gate entry (gate in)',
  'gate_out': 'Gate out',
};

String vttSourceLabel(String source) => switch (source) {
      'vehicle_report' => 'QR report',
      'gate_entry_in' => 'Gate entry',
      'gate_out' => 'Gate out',
      _ => 'Tap',
    };

class VttSettings {
  const VttSettings({
    required this.enabled,
    required this.reviseWindowHours,
    required this.amberPercent,
    required this.activeCheckpoints,
    required this.canManage,
    required this.canRecord,
  });

  final bool enabled;
  final int reviseWindowHours;
  final int amberPercent;
  final int activeCheckpoints;
  final bool canManage;
  final bool canRecord;

  factory VttSettings.fromJson(Map<String, dynamic> j) => VttSettings(
        enabled: _b(j['enabled']),
        reviseWindowHours: _i(j['reviseWindowHours']) ?? 24,
        amberPercent: _i(j['amberPercent']) ?? 20,
        activeCheckpoints: _i(j['activeCheckpoints']) ?? 0,
        canManage: _b(j['canManage']),
        canRecord: _b(j['canRecord']),
      );
}

class VttUser {
  const VttUser({required this.id, required this.name, required this.role});
  final String id;
  final String name;
  final String role;

  factory VttUser.fromJson(Map<String, dynamic> j) =>
      VttUser(id: _s(j['id']), name: _s(j['name']), role: _s(j['role']));
}

class VttTarget {
  const VttTarget({this.categoryId, required this.minutes});
  final String? categoryId;
  final int minutes;
}

class VttCheckpoint {
  const VttCheckpoint({
    required this.id,
    required this.name,
    required this.kind,
    this.site,
    required this.isMandatory,
    required this.isActive,
    this.autoSource,
    this.used = false,
    this.users = const [],
    this.targets = const [],
  });

  final String id;
  final String name;
  final String kind;
  final String? site;
  final bool isMandatory;
  final bool isActive;
  final String? autoSource;
  final bool used;
  final List<VttUser> users;
  final List<VttTarget> targets;

  /// The all-vehicles target, if any.
  int? get defaultTarget {
    for (final t in targets) {
      if (t.categoryId == null) return t.minutes;
    }
    return null;
  }

  int? targetFor(String? categoryId) {
    for (final t in targets) {
      if (t.categoryId == categoryId) return t.minutes;
    }
    return null;
  }

  factory VttCheckpoint.fromJson(Map<String, dynamic> j) => VttCheckpoint(
        id: _s(j['id']),
        name: _s(j['name']),
        kind: _s(j['kind']).isEmpty ? 'custom' : _s(j['kind']),
        site: _sn(j['site']),
        isMandatory: j['isMandatory'] != false,
        isActive: j['isActive'] != false,
        autoSource: _sn(j['autoSource']),
        used: _b(j['used']),
        users: _list(j['users']).map(VttUser.fromJson).toList(),
        targets: _list(j['targets'])
            .map((t) => VttTarget(categoryId: _sn(t['categoryId']), minutes: _i(t['minutes']) ?? 0))
            .where((t) => t.minutes > 0)
            .toList(),
      );
}

class VttTemplate {
  const VttTemplate({
    required this.key,
    required this.name,
    required this.description,
    required this.needsSites,
    required this.checkpoints,
  });

  final String key;
  final String name;
  final String description;
  final bool needsSites;
  final List<String> checkpoints;

  factory VttTemplate.fromJson(Map<String, dynamic> j) => VttTemplate(
        key: _s(j['key']),
        name: _s(j['name']),
        description: _s(j['description']),
        needsSites: _b(j['needsSites']),
        checkpoints: _list(j['checkpoints']).map((c) => _s(c['name'])).toList(),
      );
}

class VttCategory {
  const VttCategory({required this.id, required this.name, this.description, required this.isActive});
  final String id;
  final String name;
  final String? description;
  final bool isActive;

  factory VttCategory.fromJson(Map<String, dynamic> j) => VttCategory(
        id: _s(j['id']),
        name: _s(j['name']),
        description: _sn(j['description']),
        isActive: j['isActive'] != false,
      );
}

class VttVehicle {
  const VttVehicle({
    required this.id,
    required this.vehicleNo,
    this.categoryId,
    this.category,
    this.capacity,
    this.transporter,
    this.hoursPerDay,
    required this.isActive,
  });

  final String id;
  final String vehicleNo;
  final String? categoryId;
  final String? category;
  final String? capacity;
  final String? transporter;
  final double? hoursPerDay;
  final bool isActive;

  factory VttVehicle.fromJson(Map<String, dynamic> j) => VttVehicle(
        id: _s(j['id']),
        vehicleNo: _s(j['vehicleNo']),
        categoryId: _sn(j['categoryId']),
        category: _sn(j['category']),
        capacity: _sn(j['capacity']),
        transporter: _sn(j['transporter']),
        hoursPerDay: j['hoursPerDay'] is num ? (j['hoursPerDay'] as num).toDouble() : null,
        isActive: j['isActive'] != false,
      );
}

/// One recorded time on a trip.
class VttEntry {
  const VttEntry({
    required this.id,
    required this.checkpoint,
    this.site,
    required this.at,
    required this.recordedAt,
    this.recordedBy,
    required this.source,
    this.remark,
    required this.revised,
    this.revisedBy,
    this.revisedOn,
    this.revisionReason,
    this.gateEntryNo,
    this.countSheetNo,
    this.segmentMinutes,
    this.targetMinutes,
    this.status,
    required this.canRevise,
  });

  final String id;
  final String checkpoint;
  final String? site;

  /// The time that counts (corrected, when it was).
  final DateTime? at;

  /// As first recorded (never changes).
  final DateTime? recordedAt;
  final String? recordedBy;
  final String source;
  final String? remark;
  final bool revised;
  final String? revisedBy;
  final DateTime? revisedOn;
  final String? revisionReason;
  final String? gateEntryNo;
  final String? countSheetNo;

  /// The step ending here, from the time before it.
  final int? segmentMinutes;
  final int? targetMinutes;

  /// green / amber / red against the target, or null.
  final String? status;
  final bool canRevise;

  factory VttEntry.fromJson(Map<String, dynamic> j) => VttEntry(
        id: _s(j['id']),
        checkpoint: _s(j['checkpoint']),
        site: _sn(j['site']),
        at: _d(j['at']),
        recordedAt: _d(j['recordedAt']),
        recordedBy: _sn(j['recordedBy']),
        source: _s(j['source']).isEmpty ? 'tap' : _s(j['source']),
        remark: _sn(j['remark']),
        revised: _b(j['revised']),
        revisedBy: _sn(j['revisedBy']),
        revisedOn: _d(j['revisedOn']),
        revisionReason: _sn(j['revisionReason']),
        gateEntryNo: _sn(j['gateEntryNo']),
        countSheetNo: _sn(j['countSheetNo']),
        segmentMinutes: _i(j['segmentMinutes']),
        targetMinutes: _i(j['targetMinutes']),
        status: _sn(j['status']),
        canRevise: _b(j['canRevise']),
      );
}

class VttTrip {
  const VttTrip({
    required this.id,
    required this.vehicleId,
    required this.vehicleNo,
    this.category,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.closedBy,
    this.closeReason,
    required this.entries,
    required this.remaining,
    this.totalMinutes,
    this.totalTargetMinutes,
    this.totalStatus,
  });

  final String id;
  final String vehicleId;
  final String vehicleNo;
  final String? category;

  /// open / completed / cancelled.
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? closedBy;
  final String? closeReason;
  final List<VttEntry> entries;

  /// Checkpoints still to come (open trips).
  final List<String> remaining;
  final int? totalMinutes;
  final int? totalTargetMinutes;
  final String? totalStatus;

  bool get isOpen => status == 'open';

  factory VttTrip.fromJson(Map<String, dynamic> j) => VttTrip(
        id: _s(j['id']),
        vehicleId: _s(j['vehicleId']),
        vehicleNo: _s(j['vehicleNo']),
        category: _sn(j['category']),
        status: _s(j['status']),
        startedAt: _d(j['startedAt']),
        endedAt: _d(j['endedAt']),
        closedBy: _sn(j['closedBy']),
        closeReason: _sn(j['closeReason']),
        entries: _list(j['entries']).map(VttEntry.fromJson).toList(),
        remaining: j['remaining'] is List ? (j['remaining'] as List).map(_s).toList() : const [],
        totalMinutes: _i(j['totalMinutes']),
        totalTargetMinutes: _i(j['totalTargetMinutes']),
        totalStatus: _sn(j['totalStatus']),
      );
}

class VttRecordable {
  const VttRecordable({required this.id, required this.name, this.site, this.autoSource});
  final String id;
  final String name;
  final String? site;
  final String? autoSource;
}

/// A vehicle on the live board.
class VttBoardRow {
  const VttBoardRow({
    required this.vehicleId,
    required this.vehicleNo,
    this.category,
    this.transporter,
    this.trip,
    this.lastCheckpoint,
    this.lastAt,
    this.nextCheckpoint,
    this.elapsedMinutes,
    this.targetMinutes,
    this.status,
    required this.stale,
    required this.canRecord,
    this.lastTripEndedAt,
  });

  final String vehicleId;
  final String vehicleNo;
  final String? category;
  final String? transporter;
  final VttTrip? trip;
  final String? lastCheckpoint;
  final DateTime? lastAt;
  final String? nextCheckpoint;
  final int? elapsedMinutes;
  final int? targetMinutes;
  final String? status;

  /// Trip running for over a day: likely a missed checkpoint.
  final bool stale;
  final List<VttRecordable> canRecord;
  final DateTime? lastTripEndedAt;

  factory VttBoardRow.fromJson(Map<String, dynamic> j) {
    final last = j['lastCheckpoint'];
    final next = j['nextCheckpoint'];
    final trip = j['trip'];
    return VttBoardRow(
      vehicleId: _s(j['vehicleId']),
      vehicleNo: _s(j['vehicleNo']),
      category: _sn(j['category']),
      transporter: _sn(j['transporter']),
      trip: trip is Map<String, dynamic> ? VttTrip.fromJson(trip) : null,
      lastCheckpoint: last is Map ? _sn(last['name']) : null,
      lastAt: last is Map ? _d(last['at']) : null,
      nextCheckpoint: next is Map ? _sn(next['name']) : null,
      elapsedMinutes: _i(j['elapsedMinutes']),
      targetMinutes: _i(j['targetMinutes']),
      status: _sn(j['status']),
      stale: _b(j['stale']),
      canRecord: _list(j['canRecord'])
          .map((c) => VttRecordable(
                id: _s(c['id']),
                name: _s(c['name']),
                site: _sn(c['site']),
                autoSource: _sn(c['autoSource']),
              ))
          .toList(),
      lastTripEndedAt: _d(j['lastTripEndedAt']),
    );
  }
}

class VttBoard {
  const VttBoard({required this.checkpoints, required this.vehicles});
  final List<VttCheckpoint> checkpoints;
  final List<VttBoardRow> vehicles;

  factory VttBoard.fromJson(Map<String, dynamic> j) => VttBoard(
        checkpoints: _list(j['checkpoints']).map(VttCheckpoint.fromJson).toList(),
        vehicles: _list(j['vehicles']).map(VttBoardRow.fromJson).toList(),
      );
}

class VttTripPage {
  const VttTripPage({required this.trips, required this.page, required this.totalPages, required this.total});
  final List<VttTrip> trips;
  final int page;
  final int totalPages;
  final int total;
}
