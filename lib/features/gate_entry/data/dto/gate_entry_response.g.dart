// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gate_entry_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GateEntryResponse _$GateEntryResponseFromJson(Map<String, dynamic> json) =>
    GateEntryResponse(
      id: json['id'] as String,
      gateEntryNo: json['gateEntryNo'] as String,
      gateTimestamp: json['gateTimestamp'] as String?,
      gateMovement: json['gateMovement'] as String,
      challanNo: json['challanNo'] as String,
      lrNumber: json['lrNumber'] as String,
      transporterName: json['transporterName'] as String,
      vehicleNo: json['vehicleNo'] as String,
      driverContactNo: json['driverContactNo'] as String,
      vendorCode: json['vendorCode'] as String,
      vendorName: json['vendorName'] as String,
      status: json['status'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => GateEntryItemResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      gateOutTimestamp: json['gateOutTimestamp'] as String?,
      gateOutBy: json['gateOutBy'] as String?,
      noOfLineItems: (json['noOfLineItems'] as num?)?.toInt(),
      remark: json['remark'] as String?,
      countSheetNo: json['countSheetNo'] as String?,
    );

Map<String, dynamic> _$GateEntryResponseToJson(GateEntryResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gateEntryNo': instance.gateEntryNo,
      'gateTimestamp': instance.gateTimestamp,
      'gateMovement': instance.gateMovement,
      'challanNo': instance.challanNo,
      'lrNumber': instance.lrNumber,
      'transporterName': instance.transporterName,
      'vehicleNo': instance.vehicleNo,
      'driverContactNo': instance.driverContactNo,
      'vendorCode': instance.vendorCode,
      'vendorName': instance.vendorName,
      'status': instance.status,
      'items': instance.items,
      'gateOutTimestamp': instance.gateOutTimestamp,
      'gateOutBy': instance.gateOutBy,
      'noOfLineItems': instance.noOfLineItems,
      'remark': instance.remark,
      'countSheetNo': instance.countSheetNo,
    };
