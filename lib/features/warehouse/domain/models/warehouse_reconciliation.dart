/// Stable set of `reasonCode` values returned by `GET /reconciliations`.
/// The frontend matches on these exact strings (case-sensitive) — backend
/// confirmed this is the complete vocabulary as of 2026-06.
class ReasonCode {
  ReasonCode._();

  static const matched = 'MATCHED';
  static const awaitingGrn = 'AWAITING_GRN';     // pending_grn, <24h
  static const grnMissing = 'GRN_MISSING';       // grn_not_posted, >24h
  static const poOrMaterialMismatch = 'PO_OR_MATERIAL_MISMATCH';
  static const multipleGrnFound = 'MULTIPLE_GRN_FOUND'; // duplicate_grn
  static const vendorMissing = 'VENDOR_MISSING';
  static const vendorMismatch = 'VENDOR_MISMATCH';
  static const qtyMismatch = 'QTY_MISMATCH';
}

/// Row in the gate-entry-centric reconciliation list.
///
/// The backend returns three kinds of rows in `data[]`, distinguished by `id`:
///   - regular UUID  → a real reconciliation record (resolvable, navigable to
///                     the reconciliation detail screen).
///   - "gate_<uuid>" → synthetic row for a gate entry that has no GRN yet
///                     (`status: pending_grn`). Tap navigates to gate entry
///                     detail; Resolve action is hidden.
///   - "orphan_<uuid>" → synthetic row for an uploaded GRN with no matching
///                     gate entry (`status: pending_gate_entry`). Tap shows
///                     the GRN info; Resolve action is hidden.
class WarehouseReconciliationRecord {
  final String id;
  final String? gateEntryId;
  final String? gateEntryNo;
  final String challanNo;
  final String vendorName;
  final String vendorCode;
  final DateTime? gateTimestamp;
  final String gateStatus;
  final String status;
  final String statusLabel;
  final String matchedGrnNumber;
  final num qtyVariance;
  final String reasonCode;
  final String displayReason;
  final DateTime? date;
  final String reconciledBy;
  final bool isResolved;
  final DateTime? resolvedAt;
  final String resolvedBy;
  final String resolutionNotes;

  // GRN-side fields used for the comparison view on exception rows
  // (wrong_po_material / VENDOR_MISMATCH / quantity_mismatch / ...) AND
  // for the standalone orphan-GRN info sheet on `pending_gate_entry` rows.
  // For orphan rows these are the SAP GRN's own values. For matched/exception
  // rows these are the matched SAP GRN's values (gate entry's values stay in
  // `vendorName` / `vendorCode` / `challanNo`).
  final String sapGrnId;
  final String poNumber;
  final String materialCode;
  final String grnNumber;
  final num grnQty;
  final DateTime? grnPostingDate;
  final DateTime? importedAt;
  final String grnVendorName;
  final String grnVendorCode;

  /// Populated only when `reasonCode == MULTIPLE_GRN_FOUND`. Every SAP GRN
  /// number that matched this gate entry's challan — the duplicate set the
  /// operator needs to disambiguate.
  final List<String> duplicateGrnNumbers;

  const WarehouseReconciliationRecord({
    required this.id,
    required this.gateEntryId,
    required this.gateEntryNo,
    required this.challanNo,
    required this.vendorName,
    required this.vendorCode,
    required this.gateTimestamp,
    required this.gateStatus,
    required this.status,
    required this.statusLabel,
    required this.matchedGrnNumber,
    required this.qtyVariance,
    required this.reasonCode,
    required this.displayReason,
    required this.date,
    required this.reconciledBy,
    required this.isResolved,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.resolutionNotes,
    required this.sapGrnId,
    required this.poNumber,
    required this.materialCode,
    required this.grnNumber,
    required this.grnQty,
    required this.grnPostingDate,
    required this.importedAt,
    required this.grnVendorName,
    required this.grnVendorCode,
    required this.duplicateGrnNumbers,
  });

  factory WarehouseReconciliationRecord.fromJson(Map<String, dynamic> json) {
    final statusCode = (json['status'] ?? '').toString();
    final statusLabel = (json['statusLabel'] ?? '').toString();
    final qtyVariance = _readNum(json['qtyVariance']);
    final matchedGrn = (json['matchedGrnNumber'] ?? '').toString();
    final displayReason =
        (json['displayReason'] ?? json['reasonCode'] ?? '').toString();

    return WarehouseReconciliationRecord(
      id: (json['id'] ?? '').toString(),
      gateEntryId: _readNullableString(json['gateEntryId']),
      gateEntryNo: _readNullableString(json['gateEntryNo']),
      // Backend now standardised on camelCase `challanNo`. Do not re-introduce
      // snake_case / `challanNumber` fallbacks.
      challanNo: (json['challanNo'] ?? '').toString(),
      vendorName: (json['vendorName'] ?? '').toString(),
      vendorCode: (json['vendorCode'] ?? '').toString(),
      gateTimestamp: _readDate(json['gateTimestamp']),
      gateStatus: (json['gateStatus'] ?? '').toString(),
      status: statusCode,
      statusLabel: statusLabel,
      matchedGrnNumber: matchedGrn,
      qtyVariance: qtyVariance,
      reasonCode: (json['reasonCode'] ?? '').toString(),
      displayReason: displayReason,
      date: _readDate(json['reconciledAt'] ?? json['createdAt']),
      reconciledBy: (json['reconciledBy'] ?? '').toString(),
      isResolved: (json['isResolved'] ?? false) == true,
      resolvedAt: _readDate(json['resolvedAt']),
      resolvedBy: (json['resolvedBy'] ?? '').toString(),
      resolutionNotes: (json['resolutionNotes'] ?? '').toString(),
      sapGrnId: (json['sapGrnId'] ?? '').toString(),
      poNumber: (json['poNumber'] ?? '').toString(),
      materialCode: (json['materialCode'] ?? '').toString(),
      grnNumber: (json['grnNumber'] ?? matchedGrn).toString(),
      grnQty: _readNum(json['grnQty']),
      // Backend standardised on `grnPostingDate`; orphan-only payloads from
      // earlier versions used `postingDate`. Accept either.
      grnPostingDate:
          _readDate(json['grnPostingDate'] ?? json['postingDate']),
      importedAt: _readDate(json['importedAt']),
      grnVendorName: (json['grnVendorName'] ?? '').toString(),
      grnVendorCode: (json['grnVendorCode'] ?? '').toString(),
      duplicateGrnNumbers: _readStringList(json['duplicateGrnNumbers']),
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    final out = <String>[];
    for (final v in value) {
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  String get normalizedStatus => status.trim().toLowerCase();

  String get displayStatus {
    if (statusLabel.trim().isNotEmpty) return statusLabel.trim();
    return _humanize(status);
  }

  bool get isMatched => normalizedStatus == 'matched';

  /// Gate entry exists but no SAP GRN posted yet. Synthetic row, id is
  /// `gate_<uuid>`.
  bool get isPendingGrn => normalizedStatus == 'pending_grn';

  /// SAP GRN uploaded but no matching gate entry yet. Synthetic row, id is
  /// `orphan_<uuid>`.
  bool get isPendingGateEntry => normalizedStatus == 'pending_gate_entry';

/// Gate entry a manager has flagged as never receiving a GRN
  /// ("Not for Cytiva"). Deliberately neither pending nor an exception: it
  /// needs no action, and counting it as pending is what made the report
  /// overstate how many GRNs were outstanding.
  bool get isNotForGrn => normalizedStatus == 'not_for_grn';

  /// Real exceptions that require operator attention.
  bool get isException =>
      !isMatched &&
      (normalizedStatus == 'quantity_mismatch' ||
          normalizedStatus == 'duplicate_grn' ||
          normalizedStatus == 'wrong_po_material' ||
          normalizedStatus == 'grn_not_posted');

  bool get isApproved => normalizedStatus.contains('approved');
  bool get isClosed => normalizedStatus.contains('closed');
  bool get isActive => !isClosed;

  /// Only real reconciliation rows have a regular UUID — synthetic
  /// `gate_<uuid>` / `orphan_<uuid>` rows can't be resolved server-side.
  bool get isSyntheticRow =>
      id.startsWith('gate_') || id.startsWith('orphan_');

  bool get canResolve => !isSyntheticRow && !isResolved;

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  static num _readNum(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;
    return num.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String _humanize(String value) {
    if (value.trim().isEmpty) return 'Unknown';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// Per-status counters returned by `reconciliation.summary.gateEntries.byStatus`.
class WarehouseReconciliationStatusBreakdown {
  final int matched;
  final int pendingGrn;
  final int grnNotPosted;
  final int quantityMismatch;
  final int duplicateGrn;
  final int wrongPoMaterial;

  const WarehouseReconciliationStatusBreakdown({
    this.matched = 0,
    this.pendingGrn = 0,
    this.grnNotPosted = 0,
    this.quantityMismatch = 0,
    this.duplicateGrn = 0,
    this.wrongPoMaterial = 0,
  });

  factory WarehouseReconciliationStatusBreakdown.fromJson(
      Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return WarehouseReconciliationStatusBreakdown(
      matched: read('matched'),
      pendingGrn: read('pendingGrn'),
      grnNotPosted: read('grnNotPosted'),
      quantityMismatch: read('quantityMismatch'),
      duplicateGrn: read('duplicateGrn'),
      wrongPoMaterial: read('wrongPoMaterial'),
    );
  }

  int get totalExceptions =>
      grnNotPosted + quantityMismatch + duplicateGrn + wrongPoMaterial;
}

class WarehouseReconciliationSummary {
  final int matched;
  final int pending;
  final int exception;

  const WarehouseReconciliationSummary({
    required this.matched,
    required this.pending,
    required this.exception,
  });
}

class WarehouseManagerDashboardSummary {
  final int pendingApproval;
  final int exceptions;
  final int approvedToday;

  const WarehouseManagerDashboardSummary({
    required this.pendingApproval,
    required this.exceptions,
    required this.approvedToday,
  });
}

class WarehouseReconciliationActionRequest {
  final String actorKey;
  final String actorId;
  final String remarks;

  const WarehouseReconciliationActionRequest({
    required this.actorKey,
    required this.actorId,
    required this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      actorKey: actorId,
      'remarks': remarks,
    };
  }
}
