// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gate_entry_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GateEntryResponse {
  String get id => throw _privateConstructorUsedError;
  String get gateEntryNo => throw _privateConstructorUsedError;
  String? get gateTimestamp => throw _privateConstructorUsedError;
  String get gateMovement => throw _privateConstructorUsedError;
  String get challanNo => throw _privateConstructorUsedError;
  String get lrNumber => throw _privateConstructorUsedError;
  String get transporterName => throw _privateConstructorUsedError;
  String get vehicleNo => throw _privateConstructorUsedError;
  String get driverContactNo => throw _privateConstructorUsedError;
  String get vendorCode => throw _privateConstructorUsedError;
  String get vendorName => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  List<GateEntryItemResponse> get items => throw _privateConstructorUsedError;
  String? get gateOutTimestamp => throw _privateConstructorUsedError;
  String? get gateOutBy => throw _privateConstructorUsedError;
  int? get noOfLineItems => throw _privateConstructorUsedError;
  String? get remark => throw _privateConstructorUsedError;
  String? get countSheetNo => throw _privateConstructorUsedError;

  /// Create a copy of GateEntryResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GateEntryResponseCopyWith<GateEntryResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GateEntryResponseCopyWith<$Res> {
  factory $GateEntryResponseCopyWith(
          GateEntryResponse value, $Res Function(GateEntryResponse) then) =
      _$GateEntryResponseCopyWithImpl<$Res, GateEntryResponse>;
  @useResult
  $Res call(
      {String id,
      String gateEntryNo,
      String? gateTimestamp,
      String gateMovement,
      String challanNo,
      String lrNumber,
      String transporterName,
      String vehicleNo,
      String driverContactNo,
      String vendorCode,
      String vendorName,
      String? status,
      List<GateEntryItemResponse> items,
      String? gateOutTimestamp,
      String? gateOutBy,
      int? noOfLineItems,
      String? remark,
      String? countSheetNo});
}

/// @nodoc
class _$GateEntryResponseCopyWithImpl<$Res, $Val extends GateEntryResponse>
    implements $GateEntryResponseCopyWith<$Res> {
  _$GateEntryResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GateEntryResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gateEntryNo = null,
    Object? gateTimestamp = freezed,
    Object? gateMovement = null,
    Object? challanNo = null,
    Object? lrNumber = null,
    Object? transporterName = null,
    Object? vehicleNo = null,
    Object? driverContactNo = null,
    Object? vendorCode = null,
    Object? vendorName = null,
    Object? status = freezed,
    Object? items = null,
    Object? gateOutTimestamp = freezed,
    Object? gateOutBy = freezed,
    Object? noOfLineItems = freezed,
    Object? remark = freezed,
    Object? countSheetNo = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      gateTimestamp: freezed == gateTimestamp
          ? _value.gateTimestamp
          : gateTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
      gateMovement: null == gateMovement
          ? _value.gateMovement
          : gateMovement // ignore: cast_nullable_to_non_nullable
              as String,
      challanNo: null == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String,
      lrNumber: null == lrNumber
          ? _value.lrNumber
          : lrNumber // ignore: cast_nullable_to_non_nullable
              as String,
      transporterName: null == transporterName
          ? _value.transporterName
          : transporterName // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleNo: null == vehicleNo
          ? _value.vehicleNo
          : vehicleNo // ignore: cast_nullable_to_non_nullable
              as String,
      driverContactNo: null == driverContactNo
          ? _value.driverContactNo
          : driverContactNo // ignore: cast_nullable_to_non_nullable
              as String,
      vendorCode: null == vendorCode
          ? _value.vendorCode
          : vendorCode // ignore: cast_nullable_to_non_nullable
              as String,
      vendorName: null == vendorName
          ? _value.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<GateEntryItemResponse>,
      gateOutTimestamp: freezed == gateOutTimestamp
          ? _value.gateOutTimestamp
          : gateOutTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
      gateOutBy: freezed == gateOutBy
          ? _value.gateOutBy
          : gateOutBy // ignore: cast_nullable_to_non_nullable
              as String?,
      noOfLineItems: freezed == noOfLineItems
          ? _value.noOfLineItems
          : noOfLineItems // ignore: cast_nullable_to_non_nullable
              as int?,
      remark: freezed == remark
          ? _value.remark
          : remark // ignore: cast_nullable_to_non_nullable
              as String?,
      countSheetNo: freezed == countSheetNo
          ? _value.countSheetNo
          : countSheetNo // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GateEntryResponseImplCopyWith<$Res>
    implements $GateEntryResponseCopyWith<$Res> {
  factory _$$GateEntryResponseImplCopyWith(_$GateEntryResponseImpl value,
          $Res Function(_$GateEntryResponseImpl) then) =
      __$$GateEntryResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String gateEntryNo,
      String? gateTimestamp,
      String gateMovement,
      String challanNo,
      String lrNumber,
      String transporterName,
      String vehicleNo,
      String driverContactNo,
      String vendorCode,
      String vendorName,
      String? status,
      List<GateEntryItemResponse> items,
      String? gateOutTimestamp,
      String? gateOutBy,
      int? noOfLineItems,
      String? remark,
      String? countSheetNo});
}

/// @nodoc
class __$$GateEntryResponseImplCopyWithImpl<$Res>
    extends _$GateEntryResponseCopyWithImpl<$Res, _$GateEntryResponseImpl>
    implements _$$GateEntryResponseImplCopyWith<$Res> {
  __$$GateEntryResponseImplCopyWithImpl(_$GateEntryResponseImpl _value,
      $Res Function(_$GateEntryResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of GateEntryResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gateEntryNo = null,
    Object? gateTimestamp = freezed,
    Object? gateMovement = null,
    Object? challanNo = null,
    Object? lrNumber = null,
    Object? transporterName = null,
    Object? vehicleNo = null,
    Object? driverContactNo = null,
    Object? vendorCode = null,
    Object? vendorName = null,
    Object? status = freezed,
    Object? items = null,
    Object? gateOutTimestamp = freezed,
    Object? gateOutBy = freezed,
    Object? noOfLineItems = freezed,
    Object? remark = freezed,
    Object? countSheetNo = freezed,
  }) {
    return _then(_$GateEntryResponseImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      gateTimestamp: freezed == gateTimestamp
          ? _value.gateTimestamp
          : gateTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
      gateMovement: null == gateMovement
          ? _value.gateMovement
          : gateMovement // ignore: cast_nullable_to_non_nullable
              as String,
      challanNo: null == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String,
      lrNumber: null == lrNumber
          ? _value.lrNumber
          : lrNumber // ignore: cast_nullable_to_non_nullable
              as String,
      transporterName: null == transporterName
          ? _value.transporterName
          : transporterName // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleNo: null == vehicleNo
          ? _value.vehicleNo
          : vehicleNo // ignore: cast_nullable_to_non_nullable
              as String,
      driverContactNo: null == driverContactNo
          ? _value.driverContactNo
          : driverContactNo // ignore: cast_nullable_to_non_nullable
              as String,
      vendorCode: null == vendorCode
          ? _value.vendorCode
          : vendorCode // ignore: cast_nullable_to_non_nullable
              as String,
      vendorName: null == vendorName
          ? _value.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<GateEntryItemResponse>,
      gateOutTimestamp: freezed == gateOutTimestamp
          ? _value.gateOutTimestamp
          : gateOutTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
      gateOutBy: freezed == gateOutBy
          ? _value.gateOutBy
          : gateOutBy // ignore: cast_nullable_to_non_nullable
              as String?,
      noOfLineItems: freezed == noOfLineItems
          ? _value.noOfLineItems
          : noOfLineItems // ignore: cast_nullable_to_non_nullable
              as int?,
      remark: freezed == remark
          ? _value.remark
          : remark // ignore: cast_nullable_to_non_nullable
              as String?,
      countSheetNo: freezed == countSheetNo
          ? _value.countSheetNo
          : countSheetNo // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$GateEntryResponseImpl implements _GateEntryResponse {
  const _$GateEntryResponseImpl(
      {required this.id,
      required this.gateEntryNo,
      this.gateTimestamp,
      required this.gateMovement,
      required this.challanNo,
      this.lrNumber = '',
      required this.transporterName,
      required this.vehicleNo,
      this.driverContactNo = '',
      this.vendorCode = '',
      required this.vendorName,
      this.status,
      required final List<GateEntryItemResponse> items,
      this.gateOutTimestamp,
      this.gateOutBy,
      this.noOfLineItems,
      this.remark,
      this.countSheetNo})
      : _items = items;

  @override
  final String id;
  @override
  final String gateEntryNo;
  @override
  final String? gateTimestamp;
  @override
  final String gateMovement;
  @override
  final String challanNo;
  @override
  @JsonKey()
  final String lrNumber;
  @override
  final String transporterName;
  @override
  final String vehicleNo;
  @override
  @JsonKey()
  final String driverContactNo;
  @override
  @JsonKey()
  final String vendorCode;
  @override
  final String vendorName;
  @override
  final String? status;
  final List<GateEntryItemResponse> _items;
  @override
  List<GateEntryItemResponse> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? gateOutTimestamp;
  @override
  final String? gateOutBy;
  @override
  final int? noOfLineItems;
  @override
  final String? remark;
  @override
  final String? countSheetNo;

  @override
  String toString() {
    return 'GateEntryResponse(id: $id, gateEntryNo: $gateEntryNo, gateTimestamp: $gateTimestamp, gateMovement: $gateMovement, challanNo: $challanNo, lrNumber: $lrNumber, transporterName: $transporterName, vehicleNo: $vehicleNo, driverContactNo: $driverContactNo, vendorCode: $vendorCode, vendorName: $vendorName, status: $status, items: $items, gateOutTimestamp: $gateOutTimestamp, gateOutBy: $gateOutBy, noOfLineItems: $noOfLineItems, remark: $remark, countSheetNo: $countSheetNo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GateEntryResponseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gateEntryNo, gateEntryNo) ||
                other.gateEntryNo == gateEntryNo) &&
            (identical(other.gateTimestamp, gateTimestamp) ||
                other.gateTimestamp == gateTimestamp) &&
            (identical(other.gateMovement, gateMovement) ||
                other.gateMovement == gateMovement) &&
            (identical(other.challanNo, challanNo) ||
                other.challanNo == challanNo) &&
            (identical(other.lrNumber, lrNumber) ||
                other.lrNumber == lrNumber) &&
            (identical(other.transporterName, transporterName) ||
                other.transporterName == transporterName) &&
            (identical(other.vehicleNo, vehicleNo) ||
                other.vehicleNo == vehicleNo) &&
            (identical(other.driverContactNo, driverContactNo) ||
                other.driverContactNo == driverContactNo) &&
            (identical(other.vendorCode, vendorCode) ||
                other.vendorCode == vendorCode) &&
            (identical(other.vendorName, vendorName) ||
                other.vendorName == vendorName) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.gateOutTimestamp, gateOutTimestamp) ||
                other.gateOutTimestamp == gateOutTimestamp) &&
            (identical(other.gateOutBy, gateOutBy) ||
                other.gateOutBy == gateOutBy) &&
            (identical(other.noOfLineItems, noOfLineItems) ||
                other.noOfLineItems == noOfLineItems) &&
            (identical(other.remark, remark) || other.remark == remark) &&
            (identical(other.countSheetNo, countSheetNo) ||
                other.countSheetNo == countSheetNo));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      gateEntryNo,
      gateTimestamp,
      gateMovement,
      challanNo,
      lrNumber,
      transporterName,
      vehicleNo,
      driverContactNo,
      vendorCode,
      vendorName,
      status,
      const DeepCollectionEquality().hash(_items),
      gateOutTimestamp,
      gateOutBy,
      noOfLineItems,
      remark,
      countSheetNo);

  /// Create a copy of GateEntryResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GateEntryResponseImplCopyWith<_$GateEntryResponseImpl> get copyWith =>
      __$$GateEntryResponseImplCopyWithImpl<_$GateEntryResponseImpl>(
          this, _$identity);
}

abstract class _GateEntryResponse implements GateEntryResponse {
  const factory _GateEntryResponse(
      {required final String id,
      required final String gateEntryNo,
      final String? gateTimestamp,
      required final String gateMovement,
      required final String challanNo,
      final String lrNumber,
      required final String transporterName,
      required final String vehicleNo,
      final String driverContactNo,
      final String vendorCode,
      required final String vendorName,
      final String? status,
      required final List<GateEntryItemResponse> items,
      final String? gateOutTimestamp,
      final String? gateOutBy,
      final int? noOfLineItems,
      final String? remark,
      final String? countSheetNo}) = _$GateEntryResponseImpl;

  @override
  String get id;
  @override
  String get gateEntryNo;
  @override
  String? get gateTimestamp;
  @override
  String get gateMovement;
  @override
  String get challanNo;
  @override
  String get lrNumber;
  @override
  String get transporterName;
  @override
  String get vehicleNo;
  @override
  String get driverContactNo;
  @override
  String get vendorCode;
  @override
  String get vendorName;
  @override
  String? get status;
  @override
  List<GateEntryItemResponse> get items;
  @override
  String? get gateOutTimestamp;
  @override
  String? get gateOutBy;
  @override
  int? get noOfLineItems;
  @override
  String? get remark;
  @override
  String? get countSheetNo;

  /// Create a copy of GateEntryResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GateEntryResponseImplCopyWith<_$GateEntryResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
