import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/network/pagination_model.dart';
import '../../../gate_entry/domain/models/gate_entry_summary.dart';

part 'report_models.freezed.dart';
part 'report_models.g.dart';

@freezed
class ReportFilter with _$ReportFilter {
  const factory ReportFilter({
    DateTime? startDate,
    DateTime? endDate,
    String? vendorFilter,
    String? poFilter,
  }) = _ReportFilter;

  factory ReportFilter.fromJson(Map<String, dynamic> json) =>
      _$ReportFilterFromJson(json);
}

@freezed
class GateEntryReportItem with _$GateEntryReportItem {
  const factory GateEntryReportItem({
    required String gateEntryNo,
    required String direction,
    required String challanNo,
    required String lrNo,
    required DateTime date,
    DateTime? gateOutDate,
    required String material,
    required int qty,
    required String vendor,
    required String vendorCode,
    required String transporter,
    required String vehicleNo,
    required String poNumber,
    required String status,
  }) = _GateEntryReportItem;

  factory GateEntryReportItem.fromJson(Map<String, dynamic> json) =>
      _$GateEntryReportItemFromJson(json);
}

@freezed
class GrnReconReportItem with _$GrnReconReportItem {
  @JsonSerializable(createToJson: false)
  const factory GrnReconReportItem({
    @JsonKey(name: 'gate_entry_no') String? gateEntryNo,
    @JsonKey(name: 'grn_no') String? grnNo,
    @JsonKey(name: 'po_number') String? poNumber,
    @JsonKey(name: 'challan_no') String? challanNo,
    @JsonKey(name: 'matched_status') String? matchedStatus,
    @JsonKey(name: 'quantity_diff') double? quantityDiff,
    @JsonKey(name: 'vendor_name') String? vendorName,
    @JsonKey(name: 'reconciled_at') String? reconciledAt,
    @JsonKey(name: 'sr_no') String? srNo,
    @JsonKey(name: 'remarks') String? remarks,
    @JsonKey(name: 'duplicate_reference') String? duplicateReference,
    @JsonKey(name: 'dublicate') String? dublicate,
    @JsonKey(name: 'reference_no') String? referenceNo,
    @JsonKey(name: 'reference') String? reference,
    @JsonKey(name: 'document_date') String? documentDate,
    @JsonKey(name: 'quantity') String? quantity,
    @JsonKey(name: 'material') String? material,
    @JsonKey(name: 'material_document') String? materialDocument,
    @JsonKey(name: 'posting_date') String? postingDate,
    @JsonKey(name: 'plant') String? plant,
    @JsonKey(name: 'material_description') String? materialDescription,
    @JsonKey(name: 'movement_type') String? movementType,
    @JsonKey(name: 'movement_type_text') String? movementTypeText,
    @JsonKey(name: 'supplier') String? supplier,
    @JsonKey(name: 'purchase_order') String? purchaseOrder,
    @JsonKey(name: 'document_header_text') String? documentHeaderText,
    @JsonKey(name: 'user_name') String? userName,
    @JsonKey(name: 'entry_date') String? entryDate,
    @JsonKey(name: 'time_of_entry') String? timeOfEntry,
    @JsonKey(name: 'amount_in_local_currency') String? amountInLocalCurrency,
    @JsonKey(name: 'qty_in_opun') String? qtyInOpun,
    @JsonKey(name: 'qty_in_order_unit') String? qtyInOrderUnit,
    @JsonKey(name: 'local_time') String? localTime,
    @JsonKey(name: 'local_date') String? localDate,
    @JsonKey(name: 'shift') String? shift,
    @JsonKey(name: 'store_remarks') String? storeRemarks,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'aging') String? aging,
    @JsonKey(name: 'mdr') String? mdr,
    @JsonKey(name: 'scanning_invoice_status') String? scanningInvoiceStatus,
    @JsonKey(name: 'scanning_date') String? scanningDate,
    @JsonKey(name: 'vendor') String? vendor,
    @JsonKey(name: 'source_vendor_name') String? sourceVendorName,
    @JsonKey(name: 'buyer_name') String? buyerName,
    @JsonKey(name: 'maker_checker') String? makerChecker,
  }) = _GrnReconReportItem;

  factory GrnReconReportItem.fromJson(Map<String, dynamic> json) {
    num readNum(dynamic value) {
      if (value is num) return value;
      if (value == null) return 0;
      return num.tryParse(value.toString()) ?? 0;
    }

    String readText(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    // A protective fallback to support both snake_case and camelCase or missing values
    return _$$GrnReconReportItemImplFromJson({
      ...json,
      'gate_entry_no': readText(['gate_entry_no', 'gateEntryNo', 'gateEntryId']),
      // Orphan ("Pending Gate Entry") rows come from the server's
      // fetchOrphanGrns, which puts the number in `grnNumber` and leaves
      // `matchedGrnNumber` null. Without that key every orphan row showed a
      // blank GRN No in the report and in the Excel/PDF export — the one
      // field you need to chase the GRN up in SAP.
      'grn_no': readText(
          ['grn_no', 'grnNo', 'grnNumber', 'matchedGrnNumber', 'materialDocument']),
      'po_number': readText(['po_number', 'poNumber', 'purchaseOrder']),
      'challan_no': readText(['challan_no', 'challanNo', 'referenceNo', 'documentHeaderText']),
      'matched_status': readText(['matched_status', 'matchedStatus', 'statusLabel', 'status']),
      'quantity_diff': readNum(json['quantity_diff'] ?? json['quantityDiff'] ?? json['qtyVariance']).toDouble(),
      'vendor_name': readText(['vendor_name', 'vendorName', 'vendor', 'sourceVendorName', 'supplier']),
      'reconciled_at': readText(['reconciled_at', 'reconciledAt', 'createdAt', 'date']),
      'remarks': readText(['remarks', 'displayReason', 'resolutionNotes']),
      'status': readText(['status', 'statusLabel']),
      'mdr': readText(['mdr', 'reasonCode']),
      'user_name': readText(['user_name', 'userName', 'reconciledBy']),
    });
  }
}

@freezed
class PendingGrnReportItem with _$PendingGrnReportItem {
  const factory PendingGrnReportItem({
    required String gateEntryNo,
    required String poNumber,
    required String vendor,
    required String material,
    required int daysPending,
  }) = _PendingGrnReportItem;

  factory PendingGrnReportItem.fromJson(Map<String, dynamic> json) =>
      _$PendingGrnReportItemFromJson(json);
}

@freezed
class AuditTrailReportItem with _$AuditTrailReportItem {
  const factory AuditTrailReportItem({
    required DateTime date,
    required String user,
    required String action,
    required String entity,
    required String changes,
  }) = _AuditTrailReportItem;

  factory AuditTrailReportItem.fromJson(Map<String, dynamic> json) =>
      _$AuditTrailReportItemFromJson(json);
}

class GateEntryReportPage {
  const GateEntryReportPage({
    this.items = const [],
    this.summary = const GateEntrySummary(),
    this.pagination,
  });

  final List<GateEntryReportItem> items;
  final GateEntrySummary summary;
  final PaginationModel? pagination;
}
