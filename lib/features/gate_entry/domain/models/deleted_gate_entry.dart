/// A gate entry an admin deleted, as recorded by the server
/// (GET /gate-entries/deleted). Read-only: the entry itself is gone, this is
/// what it held plus who deleted it, when and why.
///
/// A plain class rather than freezed: it is only ever parsed and displayed.
class DeletedGateEntry {
  final String id;
  final String gateEntryId;
  final String gateEntryNo;
  final DateTime? gateTimestamp;
  final String gateDirection;
  final String? challanNo;
  final String? vendorCode;
  final String? vendorName;
  final String? vehicleNo;
  final String? status;
  final String? createdBy;
  final String reason;
  final String? deletedBy;
  final DateTime? deletedAt;
  final String? lrNumber;
  final String? transporterName;
  final String? driverContactNo;
  final String? documentDate;
  final String? remarks;
  final DateTime? gateOutTimestamp;
  final String? reconciliationStatus;
  final String? matchedGrnNumber;
  final int attachmentCount;
  final List<DeletedGateEntryItem> items;

  const DeletedGateEntry({
    required this.id,
    required this.gateEntryId,
    required this.gateEntryNo,
    required this.gateTimestamp,
    required this.gateDirection,
    required this.challanNo,
    required this.vendorCode,
    required this.vendorName,
    required this.vehicleNo,
    required this.status,
    required this.createdBy,
    required this.reason,
    required this.deletedBy,
    required this.deletedAt,
    required this.lrNumber,
    required this.transporterName,
    required this.driverContactNo,
    required this.documentDate,
    required this.remarks,
    required this.gateOutTimestamp,
    required this.reconciliationStatus,
    required this.matchedGrnNumber,
    required this.attachmentCount,
    required this.items,
  });

  factory DeletedGateEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DeletedGateEntry(
      id: _str(json['id']) ?? '',
      gateEntryId: _str(json['gateEntryId']) ?? '',
      gateEntryNo: _str(json['gateEntryNo']) ?? '',
      gateTimestamp: _date(json['gateTimestamp']),
      gateDirection: _str(json['gateDirection']) ?? 'Gate In',
      challanNo: _str(json['challanNo']),
      vendorCode: _str(json['vendorCode']),
      vendorName: _str(json['vendorName']),
      vehicleNo: _str(json['vehicleNo']),
      status: _str(json['status']),
      createdBy: _str(json['createdBy']),
      reason: _str(json['reason']) ?? '',
      deletedBy: _str(json['deletedBy']),
      deletedAt: _date(json['deletedAt']),
      lrNumber: _str(json['lrNumber']),
      transporterName: _str(json['transporterName']),
      driverContactNo: _str(json['driverContactNo']),
      documentDate: _str(json['documentDate']),
      remarks: _str(json['remarks']),
      gateOutTimestamp: _date(json['gateOutTimestamp']),
      reconciliationStatus: _str(json['reconciliationStatus']),
      matchedGrnNumber: _str(json['matchedGrnNumber']),
      attachmentCount: (json['attachmentCount'] as num?)?.toInt() ?? 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(DeletedGateEntryItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class DeletedGateEntryItem {
  final String? poNumber;
  final String? materialCode;
  final String? materialDescription;
  final double? challanQty;
  final String? uom;

  const DeletedGateEntryItem({
    required this.poNumber,
    required this.materialCode,
    required this.materialDescription,
    required this.challanQty,
    required this.uom,
  });

  factory DeletedGateEntryItem.fromJson(Map<String, dynamic> json) {
    return DeletedGateEntryItem(
      poNumber: _str(json['poNumber']),
      materialCode: _str(json['materialCode']),
      materialDescription: _str(json['materialDescription']),
      challanQty: (json['challanQty'] as num?)?.toDouble(),
      uom: _str(json['uom']),
    );
  }
}

/// One page of deleted entries.
class DeletedGateEntryPage {
  final List<DeletedGateEntry> entries;
  final int page;
  final int totalPages;
  final int total;

  const DeletedGateEntryPage({
    required this.entries,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

String? _str(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic value) {
  final s = _str(value);
  return s == null ? null : DateTime.tryParse(s);
}
