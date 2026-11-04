import 'package:freezed_annotation/freezed_annotation.dart';
import 'gate_entry_item_response.dart';

part 'gate_entry_response.freezed.dart';
part 'gate_entry_response.g.dart';

@freezed
@JsonSerializable()
class GateEntryResponse with _$GateEntryResponse {
  const factory GateEntryResponse({
    required String id,
    required String gateEntryNo,
    String? gateTimestamp,
    required String gateMovement,
    required String challanNo,
    @Default('') String lrNumber,
    required String transporterName,
    required String vehicleNo,
    @Default('') String driverContactNo,
    @Default('') String vendorCode,
    required String vendorName,
    String? status,
    required List<GateEntryItemResponse> items,
    String? gateOutTimestamp,
    String? gateOutBy,
    int? noOfLineItems,
    String? remark,
    String? countSheetNo,
  }) = _GateEntryResponse;

  factory GateEntryResponse.fromJson(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{
      ...json,
      'id': _readString(json, const ['id']),
      'gateEntryNo': _readString(
        json,
        const ['gateEntryNo', 'gate_entry_no'],
      ),
      'gateTimestamp': _readNullableString(
        json,
        const ['gateTimestamp', 'entryTime', 'createdAt'],
      ),
      'gateMovement': _readString(
        json,
        const ['gateMovement', 'gateDirection'],
      ),
      'challanNo': _readString(
        json,
        const ['challanNo', 'challanNumber'],
      ),
      'lrNumber': _readString(
        json,
        const ['lrNumber', 'lr_number'],
      ),
      'transporterName': _readString(
        json,
        const ['transporterName'],
      ),
      'vehicleNo': _readString(
        json,
        const ['vehicleNo', 'vehicleNumber'],
      ),
      'driverContactNo': _readString(
        json,
        const ['driverContactNo', 'driver_contact_no'],
      ),
      'vendorCode': _readString(
        json,
        const ['vendorCode', 'vendor_code'],
      ),
      'vendorName': _readString(
        json,
        const ['vendorName', 'vendor_name'],
      ),
      'status': _readNullableString(
        json,
        const ['status', 'statusLabel'],
      ),
      'gateOutTimestamp': _readNullableString(
        json,
        const ['gateOutTimestamp', 'gateOutTime'],
      ),
      'gateOutBy': _readNullableString(
        json,
        const ['gateOutBy'],
      ),
      'noOfLineItems': _readNullableInt(
        json,
        const ['noOfLineItems', 'no_of_line_items'],
      ),
      'remark': _readNullableString(
        json,
        const ['remark', 'remarks'],
      ),
      'countSheetNo': _readNullableString(
        json,
        const ['countSheetNo', 'count_sheet_no'],
      ),
      'items': _normalizeItems(json),
    };

    return _$GateEntryResponseFromJson(normalized);
  }
}

List<Map<String, dynamic>> _normalizeItems(Map<String, dynamic> json) {
  final topQuantity = json['quantity'] ?? json['qty'] ?? json['challanQty'];
  final topMaterial =
      json['materialCode'] ?? json['partNumber'] ?? json['part_number'];
  final topPo = json['poNumber'] ?? json['po_number'];
  final topUom = json['uom'] ?? json['unit'];
  final topChallanNo = json['challanNo'] ?? json['challanNumber'];

  final rawItems = (json['items'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();

  if (rawItems.isEmpty) {
    if (topMaterial == null && topPo == null && topQuantity == null) {
      return const [];
    }
    return [
      {
        if (topMaterial != null) 'materialCode': topMaterial,
        if (topPo != null) 'poNumber': topPo,
        if (topQuantity != null) 'quantity': topQuantity,
        if (topUom != null) 'uom': topUom,
        if (topChallanNo != null) 'challanNo': topChallanNo,
      },
    ];
  }

  return rawItems.map((item) {
    final merged = <String, dynamic>{...item};
    if (_isMissing(merged['challanQty']) &&
        _isMissing(merged['quantity']) &&
        _isMissing(merged['qty']) &&
        topQuantity != null) {
      merged['quantity'] = topQuantity;
    }
    if (_isMissing(merged['materialCode']) &&
        _isMissing(merged['partNumber']) &&
        _isMissing(merged['part_number']) &&
        topMaterial != null) {
      merged['materialCode'] = topMaterial;
    }
    if (_isMissing(merged['poNumber']) &&
        _isMissing(merged['po_number']) &&
        topPo != null) {
      merged['poNumber'] = topPo;
    }
    if (_isMissing(merged['uom']) && _isMissing(merged['unit']) && topUom != null) {
      merged['uom'] = topUom;
    }
    if (_isMissing(merged['challanNo']) &&
        _isMissing(merged['challan_no']) &&
        topChallanNo != null) {
      merged['challanNo'] = topChallanNo;
    }
    return merged;
  }).toList();
}

bool _isMissing(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.isEmpty;
  if (value is num) return value == 0;
  return false;
}

int? _readNullableInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty) return text;
  }
  return null;
}
