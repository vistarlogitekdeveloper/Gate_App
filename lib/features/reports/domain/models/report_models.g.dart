// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReportFilterImpl _$$ReportFilterImplFromJson(Map<String, dynamic> json) =>
    _$ReportFilterImpl(
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      vendorFilter: json['vendorFilter'] as String?,
      poFilter: json['poFilter'] as String?,
    );

Map<String, dynamic> _$$ReportFilterImplToJson(_$ReportFilterImpl instance) =>
    <String, dynamic>{
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'vendorFilter': instance.vendorFilter,
      'poFilter': instance.poFilter,
    };

_$GateEntryReportItemImpl _$$GateEntryReportItemImplFromJson(
        Map<String, dynamic> json) =>
    _$GateEntryReportItemImpl(
      gateEntryNo: json['gateEntryNo'] as String,
      direction: json['direction'] as String,
      challanNo: json['challanNo'] as String,
      lrNo: json['lrNo'] as String,
      date: DateTime.parse(json['date'] as String),
      gateOutDate: json['gateOutDate'] == null
          ? null
          : DateTime.parse(json['gateOutDate'] as String),
      material: json['material'] as String,
      qty: (json['qty'] as num).toInt(),
      vendor: json['vendor'] as String,
      vendorCode: json['vendorCode'] as String,
      transporter: json['transporter'] as String,
      vehicleNo: json['vehicleNo'] as String,
      poNumber: json['poNumber'] as String,
      status: json['status'] as String,
      countSheetNo: json['countSheetNo'] as String?,
    );

Map<String, dynamic> _$$GateEntryReportItemImplToJson(
        _$GateEntryReportItemImpl instance) =>
    <String, dynamic>{
      'gateEntryNo': instance.gateEntryNo,
      'direction': instance.direction,
      'challanNo': instance.challanNo,
      'lrNo': instance.lrNo,
      'date': instance.date.toIso8601String(),
      'gateOutDate': instance.gateOutDate?.toIso8601String(),
      'material': instance.material,
      'qty': instance.qty,
      'vendor': instance.vendor,
      'vendorCode': instance.vendorCode,
      'transporter': instance.transporter,
      'vehicleNo': instance.vehicleNo,
      'poNumber': instance.poNumber,
      'status': instance.status,
      'countSheetNo': instance.countSheetNo,
    };

_$GrnReconReportItemImpl _$$GrnReconReportItemImplFromJson(
        Map<String, dynamic> json) =>
    _$GrnReconReportItemImpl(
      gateEntryNo: json['gate_entry_no'] as String?,
      grnNo: json['grn_no'] as String?,
      poNumber: json['po_number'] as String?,
      challanNo: json['challan_no'] as String?,
      matchedStatus: json['matched_status'] as String?,
      quantityDiff: (json['quantity_diff'] as num?)?.toDouble(),
      vendorName: json['vendor_name'] as String?,
      reconciledAt: json['reconciled_at'] as String?,
      srNo: json['sr_no'] as String?,
      remarks: json['remarks'] as String?,
      duplicateReference: json['duplicate_reference'] as String?,
      dublicate: json['dublicate'] as String?,
      referenceNo: json['reference_no'] as String?,
      reference: json['reference'] as String?,
      documentDate: json['document_date'] as String?,
      quantity: json['quantity'] as String?,
      material: json['material'] as String?,
      materialDocument: json['material_document'] as String?,
      postingDate: json['posting_date'] as String?,
      plant: json['plant'] as String?,
      materialDescription: json['material_description'] as String?,
      movementType: json['movement_type'] as String?,
      movementTypeText: json['movement_type_text'] as String?,
      supplier: json['supplier'] as String?,
      purchaseOrder: json['purchase_order'] as String?,
      documentHeaderText: json['document_header_text'] as String?,
      userName: json['user_name'] as String?,
      entryDate: json['entry_date'] as String?,
      timeOfEntry: json['time_of_entry'] as String?,
      amountInLocalCurrency: json['amount_in_local_currency'] as String?,
      qtyInOpun: json['qty_in_opun'] as String?,
      qtyInOrderUnit: json['qty_in_order_unit'] as String?,
      localTime: json['local_time'] as String?,
      localDate: json['local_date'] as String?,
      shift: json['shift'] as String?,
      storeRemarks: json['store_remarks'] as String?,
      status: json['status'] as String?,
      aging: json['aging'] as String?,
      mdr: json['mdr'] as String?,
      scanningInvoiceStatus: json['scanning_invoice_status'] as String?,
      scanningDate: json['scanning_date'] as String?,
      vendor: json['vendor'] as String?,
      sourceVendorName: json['source_vendor_name'] as String?,
      buyerName: json['buyer_name'] as String?,
      makerChecker: json['maker_checker'] as String?,
    );

_$PendingGrnReportItemImpl _$$PendingGrnReportItemImplFromJson(
        Map<String, dynamic> json) =>
    _$PendingGrnReportItemImpl(
      gateEntryNo: json['gateEntryNo'] as String,
      poNumber: json['poNumber'] as String,
      vendor: json['vendor'] as String,
      material: json['material'] as String,
      daysPending: (json['daysPending'] as num).toInt(),
    );

Map<String, dynamic> _$$PendingGrnReportItemImplToJson(
        _$PendingGrnReportItemImpl instance) =>
    <String, dynamic>{
      'gateEntryNo': instance.gateEntryNo,
      'poNumber': instance.poNumber,
      'vendor': instance.vendor,
      'material': instance.material,
      'daysPending': instance.daysPending,
    };

_$AuditTrailReportItemImpl _$$AuditTrailReportItemImplFromJson(
        Map<String, dynamic> json) =>
    _$AuditTrailReportItemImpl(
      date: DateTime.parse(json['date'] as String),
      user: json['user'] as String,
      action: json['action'] as String,
      entity: json['entity'] as String,
      changes: json['changes'] as String,
    );

Map<String, dynamic> _$$AuditTrailReportItemImplToJson(
        _$AuditTrailReportItemImpl instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'user': instance.user,
      'action': instance.action,
      'entity': instance.entity,
      'changes': instance.changes,
    };
