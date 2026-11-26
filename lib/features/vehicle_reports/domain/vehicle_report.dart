/// A vehicle reported outside the gate by its driver (QR code form), from
/// GET /vehicle-reports. Waiting until its gate entry is made, or closed:
/// entered / removed / expired.
class VehicleReport {
  final String id;
  final String vehicleNo;
  final String? vendorCode;
  final String? vendorName;
  final String? driverName;
  final String driverContactNo;
  final String status;
  final DateTime? reportedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? closeReason;
  final String? gateEntryId;
  final String? gateEntryNo;
  final String? countSheetNo;
  final int? minutesWaiting;

  const VehicleReport({
    required this.id,
    required this.vehicleNo,
    this.vendorCode,
    this.vendorName,
    this.driverName,
    required this.driverContactNo,
    required this.status,
    this.reportedAt,
    this.closedAt,
    this.closedBy,
    this.closeReason,
    this.gateEntryId,
    this.gateEntryNo,
    this.countSheetNo,
    this.minutesWaiting,
  });

  bool get isWaiting => status == 'waiting';

  /// Minutes waited so far (waiting) or in all (closed), from the times.
  int get waitedMinutes {
    final from = reportedAt;
    if (from == null) return minutesWaiting ?? 0;
    final to = isWaiting ? DateTime.now() : (closedAt ?? DateTime.now());
    final m = to.difference(from).inMinutes;
    return m < 0 ? 0 : m;
  }

  String get waitedLabel {
    final m = waitedMinutes;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ${m % 60}m';
    return '${h ~/ 24}d ${h % 24}h';
  }

  factory VehicleReport.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? date(String key) {
      final s = text(key);
      return s == null ? null : DateTime.tryParse(s)?.toLocal();
    }

    return VehicleReport(
      id: text('id') ?? '',
      vehicleNo: text('vehicleNo') ?? '',
      vendorCode: text('vendorCode'),
      vendorName: text('vendorName'),
      driverName: text('driverName'),
      driverContactNo: text('driverContactNo') ?? '',
      status: text('status') ?? 'waiting',
      reportedAt: date('reportedAt'),
      closedAt: date('closedAt'),
      closedBy: text('closedBy'),
      closeReason: text('closeReason'),
      gateEntryId: text('gateEntryId'),
      gateEntryNo: text('gateEntryNo'),
      countSheetNo: text('countSheetNo'),
      minutesWaiting: (json['minutesWaiting'] as num?)?.toInt(),
    );
  }
}

/// One page of vehicle reports.
class VehicleReportPage {
  final List<VehicleReport> reports;
  final int page;
  final int totalPages;
  final int total;

  const VehicleReportPage({
    required this.reports,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

/// The organisation's QR link for drivers.
class VehicleReportLink {
  final String path;
  final String organisation;

  const VehicleReportLink({required this.path, required this.organisation});
}
