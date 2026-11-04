// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gate_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GateEntryImpl _$$GateEntryImplFromJson(Map<String, dynamic> json) =>
    _$GateEntryImpl(
      id: json['id'] as String,
      gateEntryNo: json['gateEntryNo'] as String?,
      gateMovement: $enumDecode(_$GateMovementEnumMap, json['gateMovement']),
      challanNo: json['challanNo'] as String,
      lrNumber: json['lrNumber'] as String? ?? '',
      transporterName: json['transporterName'] as String,
      vehicleNo: json['vehicleNo'] as String,
      driverContactNo: json['driverContactNo'] as String? ?? '',
      vendorCode: json['vendorCode'] as String? ?? '',
      vendorName: json['vendorName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => GateEntryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'Pending',
      gateTimestamp: json['gateTimestamp'] == null
          ? null
          : DateTime.parse(json['gateTimestamp'] as String),
      gateOutTimestamp: json['gateOutTimestamp'] == null
          ? null
          : DateTime.parse(json['gateOutTimestamp'] as String),
      gateOutBy: json['gateOutBy'] as String?,
      createdBy: json['createdBy'] as String?,
      noOfLineItems: (json['noOfLineItems'] as num?)?.toInt(),
      remark: json['remark'] as String?,
      countSheetNo: json['countSheetNo'] as String?,
    );

Map<String, dynamic> _$$GateEntryImplToJson(_$GateEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gateEntryNo': instance.gateEntryNo,
      'gateMovement': _$GateMovementEnumMap[instance.gateMovement]!,
      'challanNo': instance.challanNo,
      'lrNumber': instance.lrNumber,
      'transporterName': instance.transporterName,
      'vehicleNo': instance.vehicleNo,
      'driverContactNo': instance.driverContactNo,
      'vendorCode': instance.vendorCode,
      'vendorName': instance.vendorName,
      'items': instance.items,
      'status': instance.status,
      'gateTimestamp': instance.gateTimestamp?.toIso8601String(),
      'gateOutTimestamp': instance.gateOutTimestamp?.toIso8601String(),
      'gateOutBy': instance.gateOutBy,
      'createdBy': instance.createdBy,
      'noOfLineItems': instance.noOfLineItems,
      'remark': instance.remark,
      'countSheetNo': instance.countSheetNo,
    };

const _$GateMovementEnumMap = {
  GateMovement.inMovement: 'inMovement',
  GateMovement.outMovement: 'outMovement',
};
