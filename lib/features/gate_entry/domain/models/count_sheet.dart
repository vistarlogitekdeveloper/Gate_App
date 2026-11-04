// Count sheets: one number per save of Create Gate Entry (one vehicle, any
// number of invoices), shared by every gate entry that save created.
// 00001, 00002, ... per organisation, never reset or reused.

/// The number reserved for a freshly opened Create Gate Entry form
/// (POST /gate-entries/count-sheets/reserve). Sent back as `countSheetId`
/// when the form is saved.
class ReservedCountSheet {
  final String id;
  final String countSheetNo;

  const ReservedCountSheet({required this.id, required this.countSheetNo});

  static ReservedCountSheet? tryParse(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final id = (data['id'] ?? '').toString();
    final no = (data['countSheetNo'] ?? '').toString();
    if (id.isEmpty || no.isEmpty) return null;
    return ReservedCountSheet(id: id, countSheetNo: no);
  }
}

/// One row of the Count Sheets list (GET /gate-entries/count-sheets).
class CountSheetSummary {
  final String countSheetNo;
  final DateTime? gateTimestamp;
  final DateTime? gateOutTimestamp;
  final int entryCount;
  final int gatedOutCount;
  final int closedCount;
  final int itemCount;
  final double totalQuantity;
  final String? challanNos;
  final String? vendorNames;
  final String? vendorCodes;
  final String? vehicleNos;
  final String gateDirection;
  final String? createdBy;

  const CountSheetSummary({
    required this.countSheetNo,
    required this.gateTimestamp,
    required this.gateOutTimestamp,
    required this.entryCount,
    required this.gatedOutCount,
    required this.closedCount,
    required this.itemCount,
    required this.totalQuantity,
    required this.challanNos,
    required this.vendorNames,
    required this.vendorCodes,
    required this.vehicleNos,
    required this.gateDirection,
    required this.createdBy,
  });

  /// Every vehicle of this sheet has gone out again.
  bool get allGatedOut => entryCount > 0 && gatedOutCount >= entryCount;

  factory CountSheetSummary.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    DateTime? date(String key) {
      final s = text(key);
      return s == null ? null : DateTime.tryParse(s);
    }

    return CountSheetSummary(
      countSheetNo: text('countSheetNo') ?? '',
      gateTimestamp: date('gateTimestamp'),
      gateOutTimestamp: date('gateOutTimestamp'),
      entryCount: count('entryCount'),
      gatedOutCount: count('gatedOutCount'),
      closedCount: count('closedCount'),
      itemCount: count('itemCount'),
      totalQuantity: (json['totalQuantity'] as num?)?.toDouble() ?? 0,
      challanNos: text('challanNos'),
      vendorNames: text('vendorNames'),
      vendorCodes: text('vendorCodes'),
      vehicleNos: text('vehicleNos'),
      gateDirection: text('gateDirection') ?? 'Gate In',
      createdBy: text('createdBy'),
    );
  }
}

/// One page of the Count Sheets list.
class CountSheetPage {
  final List<CountSheetSummary> sheets;
  final int page;
  final int totalPages;
  final int total;

  const CountSheetPage({
    required this.sheets,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}
