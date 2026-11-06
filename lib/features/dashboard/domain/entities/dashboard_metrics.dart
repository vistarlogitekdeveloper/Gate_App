class DashboardMetrics {
  const DashboardMetrics({
    required this.totalGateEntriesOverall,
    required this.totalGateEntriesToday,
    required this.totalGateEntriesYesterday,
    required this.totalGateEntriesThisWeek,
    required this.totalGateEntriesMonth,
    required this.gateInCount,
    required this.gateOutCount,
    this.pendingGateOut = 0,
    this.myCreatedToday = 0,
    required this.totalGrnPosted,
    required this.pendingGrnCount,
    required this.quantityMismatchCases,
    required this.duplicateGrnCases,
    required this.gateTat,
    required this.dockTat,
    required this.pendingGrnAging0To1,
    required this.pendingGrnAging2To3,
    required this.pendingGrnAgingMoreThan3,
    required this.recentActivity,
    this.overdueGateOut = const [],
    this.overdueGateOutThresholdMinutes = 120,
  });

  final int totalGateEntriesOverall;
  final int totalGateEntriesToday;
  final int totalGateEntriesYesterday;
  final int totalGateEntriesThisWeek;
  final int totalGateEntriesMonth;
  final int gateInCount;
  final int gateOutCount;

  /// All-time vehicles still inside (gate_in with no gate_out). From the
  /// security dashboard's `pendingGateOut`.
  final int pendingGateOut;

  /// Entries the current user created today (security dashboard `today.myCreated`).
  final int myCreatedToday;

  final int totalGrnPosted;
  final int pendingGrnCount;
  final int quantityMismatchCases;
  final int duplicateGrnCases;
  final double gateTat;
  final double dockTat;
  final int pendingGrnAging0To1;
  final int pendingGrnAging2To3;
  final int pendingGrnAgingMoreThan3;
  final List<DailyActivity> recentActivity;

  /// Vehicles gated in but not gated out past the alert threshold.
  final List<OverdueGateOut> overdueGateOut;

  /// Minutes after gate-in at which a vehicle is flagged overdue (default 120).
  final int overdueGateOutThresholdMinutes;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    // The security-dashboard endpoint nests today's counters under `today`
    // (totalEntries / gateIn / gateOut / myCreated) and returns the 7-day
    // series as `weeklyActivity`. Older flat keys are still accepted so this
    // stays backward-compatible with any other summary shape.
    final rawToday = json['today'];
    final today =
        rawToday is Map<String, dynamic> ? rawToday : const <String, dynamic>{};

    int pick(Map<String, dynamic> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v is num) return v.toInt();
      }
      return 0;
    }

    // Prefer the nested `today.*` value; fall back to a flat top-level key.
    int fromTodayOrFlat(String todayKey, List<String> flatKeys) {
      final v = today[todayKey];
      if (v is num) return v.toInt();
      return pick(json, flatKeys);
    }

    final activity = (json['weeklyActivity'] as List<dynamic>?) ??
        (json['recentActivity'] as List<dynamic>?) ??
        const <dynamic>[];

    return DashboardMetrics(
      totalGateEntriesOverall: pick(json, ['totalGateEntriesOverall', 'total']),
      totalGateEntriesToday:
          fromTodayOrFlat('totalEntries', ['totalGateEntriesToday']),
      totalGateEntriesYesterday:
          pick(json, ['totalGateEntriesYesterday', 'yesterday']),
      totalGateEntriesThisWeek:
          pick(json, ['totalGateEntriesThisWeek', 'thisWeek']),
      totalGateEntriesMonth: pick(json, ['totalGateEntriesMonth']),
      gateInCount: fromTodayOrFlat('gateIn', ['gateInCount']),
      gateOutCount: fromTodayOrFlat('gateOut', ['gateOutCount']),
      pendingGateOut: pick(json, ['pendingGateOut']),
      myCreatedToday: fromTodayOrFlat('myCreated', ['myCreatedToday']),
      totalGrnPosted: pick(json, ['totalGrnPosted']),
      pendingGrnCount: pick(json, ['pendingGrnCount']),
      quantityMismatchCases: pick(json, ['quantityMismatchCases']),
      duplicateGrnCases: pick(json, ['duplicateGrnCases']),
      gateTat: (json['gateTat'] as num?)?.toDouble() ?? 0,
      dockTat: (json['dockTat'] as num?)?.toDouble() ?? 0,
      pendingGrnAging0To1: pick(json, ['pendingGrnAging0To1']),
      pendingGrnAging2To3: pick(json, ['pendingGrnAging2To3']),
      pendingGrnAgingMoreThan3: pick(json, ['pendingGrnAgingMoreThan3']),
      recentActivity: activity
          .whereType<Map<String, dynamic>>()
          .map(DailyActivity.fromJson)
          .toList(),
      overdueGateOut: (json['overdueGateOut'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(OverdueGateOut.fromJson)
              .toList() ??
          const [],
      overdueGateOutThresholdMinutes:
          (json['overdueGateOutThresholdMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalGateEntriesOverall': totalGateEntriesOverall,
      'totalGateEntriesToday': totalGateEntriesToday,
      'totalGateEntriesYesterday': totalGateEntriesYesterday,
      'totalGateEntriesThisWeek': totalGateEntriesThisWeek,
      'totalGateEntriesMonth': totalGateEntriesMonth,
      'gateInCount': gateInCount,
      'gateOutCount': gateOutCount,
      'pendingGateOut': pendingGateOut,
      'myCreatedToday': myCreatedToday,
      'totalGrnPosted': totalGrnPosted,
      'pendingGrnCount': pendingGrnCount,
      'quantityMismatchCases': quantityMismatchCases,
      'duplicateGrnCases': duplicateGrnCases,
      'gateTat': gateTat,
      'dockTat': dockTat,
      'pendingGrnAging0To1': pendingGrnAging0To1,
      'pendingGrnAging2To3': pendingGrnAging2To3,
      'pendingGrnAgingMoreThan3': pendingGrnAgingMoreThan3,
      'recentActivity': recentActivity.map((e) => e.toJson()).toList(),
    };
  }
}

class DailyActivity {
  const DailyActivity({
    required this.day,
    required this.entriesCount,
  });

  final String day;
  final int entriesCount;

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    // `weeklyActivity` uses dayName/count; legacy `recentActivity` uses
    // day/entriesCount.
    final label = json['dayName'] ?? json['day'] ?? '';
    return DailyActivity(
      day: label is String ? label : label.toString(),
      entriesCount: (json['count'] as num?)?.toInt() ??
          (json['entriesCount'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'entriesCount': entriesCount,
    };
  }
}

class OverdueGateOut {
  const OverdueGateOut({
    this.id = '',
    this.countSheetNo,
    required this.gateEntryNo,
    required this.vehicleNo,
    required this.vendorName,
    required this.challanNo,
    required this.minutesInside,
    this.gateTimestamp,
  });

  /// The gate entry's id -- what recording its gate out needs.
  final String id;
  /// The count sheet (= vehicle) the entry is on; null for older entries.
  final String? countSheetNo;
  final String gateEntryNo;
  final String vehicleNo;
  final String vendorName;
  final String challanNo;
  final int minutesInside;
  final String? gateTimestamp;

  /// Human-friendly time inside, e.g. "3h 12m".
  String get durationLabel {
    final h = minutesInside ~/ 60;
    final m = minutesInside % 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  factory OverdueGateOut.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    return OverdueGateOut(
      id: str(json['id']),
      countSheetNo: str(json['countSheetNo']).isEmpty
          ? null
          : str(json['countSheetNo']),
      gateEntryNo: str(json['gateEntryNo']),
      vehicleNo: str(json['vehicleNo']),
      vendorName: str(json['vendorName']),
      challanNo: str(json['challanNo']),
      minutesInside: (json['minutesInside'] as num?)?.toInt() ?? 0,
      gateTimestamp: json['gateTimestamp'] as String?,
    );
  }
}
