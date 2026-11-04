// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gate_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GateEntry _$GateEntryFromJson(Map<String, dynamic> json) {
  return _GateEntry.fromJson(json);
}

/// @nodoc
mixin _$GateEntry {
  String get id => throw _privateConstructorUsedError;
  String? get gateEntryNo => throw _privateConstructorUsedError;
  GateMovement get gateMovement => throw _privateConstructorUsedError;
  String get challanNo => throw _privateConstructorUsedError;
  String get lrNumber => throw _privateConstructorUsedError;
  String get transporterName => throw _privateConstructorUsedError;
  String get vehicleNo => throw _privateConstructorUsedError;
  String get driverContactNo => throw _privateConstructorUsedError;
  String get vendorCode => throw _privateConstructorUsedError;
  String get vendorName => throw _privateConstructorUsedError;
  List<GateEntryItem> get items => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get gateTimestamp => throw _privateConstructorUsedError;
  DateTime? get gateOutTimestamp => throw _privateConstructorUsedError;
  String? get gateOutBy => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;
  int? get noOfLineItems => throw _privateConstructorUsedError;
  String? get remark => throw _privateConstructorUsedError;
  String? get countSheetNo => throw _privateConstructorUsedError;

  /// Serializes this GateEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GateEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GateEntryCopyWith<GateEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GateEntryCopyWith<$Res> {
  factory $GateEntryCopyWith(GateEntry value, $Res Function(GateEntry) then) =
      _$GateEntryCopyWithImpl<$Res, GateEntry>;
  @useResult
  $Res call(
      {String id,
      String? gateEntryNo,
      GateMovement gateMovement,
      String challanNo,
      String lrNumber,
      String transporterName,
      String vehicleNo,
      String driverContactNo,
      String vendorCode,
      String vendorName,
      List<GateEntryItem> items,
      String status,
      DateTime? gateTimestamp,
      DateTime? gateOutTimestamp,
      String? gateOutBy,
      String? createdBy,
      int? noOfLineItems,
      String? remark,
      String? countSheetNo});
}

/// @nodoc
class _$GateEntryCopyWithImpl<$Res, $Val extends GateEntry>
    implements $GateEntryCopyWith<$Res> {
  _$GateEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GateEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gateEntryNo = freezed,
    Object? gateMovement = null,
    Object? challanNo = null,
    Object? lrNumber = null,
    Object? transporterName = null,
    Object? vehicleNo = null,
    Object? driverContactNo = null,
    Object? vendorCode = null,
    Object? vendorName = null,
    Object? items = null,
    Object? status = null,
    Object? gateTimestamp = freezed,
    Object? gateOutTimestamp = freezed,
    Object? gateOutBy = freezed,
    Object? createdBy = freezed,
    Object? noOfLineItems = freezed,
    Object? remark = freezed,
    Object? countSheetNo = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gateEntryNo: freezed == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String?,
      gateMovement: null == gateMovement
          ? _value.gateMovement
          : gateMovement // ignore: cast_nullable_to_non_nullable
              as GateMovement,
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
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<GateEntryItem>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      gateTimestamp: freezed == gateTimestamp
          ? _value.gateTimestamp
          : gateTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      gateOutTimestamp: freezed == gateOutTimestamp
          ? _value.gateOutTimestamp
          : gateOutTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      gateOutBy: freezed == gateOutBy
          ? _value.gateOutBy
          : gateOutBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
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
abstract class _$$GateEntryImplCopyWith<$Res>
    implements $GateEntryCopyWith<$Res> {
  factory _$$GateEntryImplCopyWith(
          _$GateEntryImpl value, $Res Function(_$GateEntryImpl) then) =
      __$$GateEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? gateEntryNo,
      GateMovement gateMovement,
      String challanNo,
      String lrNumber,
      String transporterName,
      String vehicleNo,
      String driverContactNo,
      String vendorCode,
      String vendorName,
      List<GateEntryItem> items,
      String status,
      DateTime? gateTimestamp,
      DateTime? gateOutTimestamp,
      String? gateOutBy,
      String? createdBy,
      int? noOfLineItems,
      String? remark,
      String? countSheetNo});
}

/// @nodoc
class __$$GateEntryImplCopyWithImpl<$Res>
    extends _$GateEntryCopyWithImpl<$Res, _$GateEntryImpl>
    implements _$$GateEntryImplCopyWith<$Res> {
  __$$GateEntryImplCopyWithImpl(
      _$GateEntryImpl _value, $Res Function(_$GateEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of GateEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gateEntryNo = freezed,
    Object? gateMovement = null,
    Object? challanNo = null,
    Object? lrNumber = null,
    Object? transporterName = null,
    Object? vehicleNo = null,
    Object? driverContactNo = null,
    Object? vendorCode = null,
    Object? vendorName = null,
    Object? items = null,
    Object? status = null,
    Object? gateTimestamp = freezed,
    Object? gateOutTimestamp = freezed,
    Object? gateOutBy = freezed,
    Object? createdBy = freezed,
    Object? noOfLineItems = freezed,
    Object? remark = freezed,
    Object? countSheetNo = freezed,
  }) {
    return _then(_$GateEntryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gateEntryNo: freezed == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String?,
      gateMovement: null == gateMovement
          ? _value.gateMovement
          : gateMovement // ignore: cast_nullable_to_non_nullable
              as GateMovement,
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
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<GateEntryItem>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      gateTimestamp: freezed == gateTimestamp
          ? _value.gateTimestamp
          : gateTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      gateOutTimestamp: freezed == gateOutTimestamp
          ? _value.gateOutTimestamp
          : gateOutTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      gateOutBy: freezed == gateOutBy
          ? _value.gateOutBy
          : gateOutBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
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
@JsonSerializable()
class _$GateEntryImpl implements _GateEntry {
  const _$GateEntryImpl(
      {required this.id,
      this.gateEntryNo,
      required this.gateMovement,
      required this.challanNo,
      this.lrNumber = '',
      required this.transporterName,
      required this.vehicleNo,
      this.driverContactNo = '',
      this.vendorCode = '',
      required this.vendorName,
      required final List<GateEntryItem> items,
      this.status = 'Pending',
      this.gateTimestamp,
      this.gateOutTimestamp,
      this.gateOutBy,
      this.createdBy,
      this.noOfLineItems,
      this.remark,
      this.countSheetNo})
      : _items = items;

  factory _$GateEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$GateEntryImplFromJson(json);

  @override
  final String id;
  @override
  final String? gateEntryNo;
  @override
  final GateMovement gateMovement;
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
  final List<GateEntryItem> _items;
  @override
  List<GateEntryItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  @JsonKey()
  final String status;
  @override
  final DateTime? gateTimestamp;
  @override
  final DateTime? gateOutTimestamp;
  @override
  final String? gateOutBy;
  @override
  final String? createdBy;
  @override
  final int? noOfLineItems;
  @override
  final String? remark;
  @override
  final String? countSheetNo;

  @override
  String toString() {
    return 'GateEntry(id: $id, gateEntryNo: $gateEntryNo, gateMovement: $gateMovement, challanNo: $challanNo, lrNumber: $lrNumber, transporterName: $transporterName, vehicleNo: $vehicleNo, driverContactNo: $driverContactNo, vendorCode: $vendorCode, vendorName: $vendorName, items: $items, status: $status, gateTimestamp: $gateTimestamp, gateOutTimestamp: $gateOutTimestamp, gateOutBy: $gateOutBy, createdBy: $createdBy, noOfLineItems: $noOfLineItems, remark: $remark, countSheetNo: $countSheetNo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GateEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gateEntryNo, gateEntryNo) ||
                other.gateEntryNo == gateEntryNo) &&
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
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.gateTimestamp, gateTimestamp) ||
                other.gateTimestamp == gateTimestamp) &&
            (identical(other.gateOutTimestamp, gateOutTimestamp) ||
                other.gateOutTimestamp == gateOutTimestamp) &&
            (identical(other.gateOutBy, gateOutBy) ||
                other.gateOutBy == gateOutBy) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.noOfLineItems, noOfLineItems) ||
                other.noOfLineItems == noOfLineItems) &&
            (identical(other.remark, remark) || other.remark == remark) &&
            (identical(other.countSheetNo, countSheetNo) ||
                other.countSheetNo == countSheetNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      gateEntryNo,
      gateMovement,
      challanNo,
      lrNumber,
      transporterName,
      vehicleNo,
      driverContactNo,
      vendorCode,
      vendorName,
      const DeepCollectionEquality().hash(_items),
      status,
      gateTimestamp,
      gateOutTimestamp,
      gateOutBy,
      createdBy,
      noOfLineItems,
      remark,
      countSheetNo);

  /// Create a copy of GateEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GateEntryImplCopyWith<_$GateEntryImpl> get copyWith =>
      __$$GateEntryImplCopyWithImpl<_$GateEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GateEntryImplToJson(
      this,
    );
  }
}

abstract class _GateEntry implements GateEntry {
  const factory _GateEntry(
      {required final String id,
      final String? gateEntryNo,
      required final GateMovement gateMovement,
      required final String challanNo,
      final String lrNumber,
      required final String transporterName,
      required final String vehicleNo,
      final String driverContactNo,
      final String vendorCode,
      required final String vendorName,
      required final List<GateEntryItem> items,
      final String status,
      final DateTime? gateTimestamp,
      final DateTime? gateOutTimestamp,
      final String? gateOutBy,
      final String? createdBy,
      final int? noOfLineItems,
      final String? remark,
      final String? countSheetNo}) = _$GateEntryImpl;

  factory _GateEntry.fromJson(Map<String, dynamic> json) =
      _$GateEntryImpl.fromJson;

  @override
  String get id;
  @override
  String? get gateEntryNo;
  @override
  GateMovement get gateMovement;
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
  List<GateEntryItem> get items;
  @override
  String get status;
  @override
  DateTime? get gateTimestamp;
  @override
  DateTime? get gateOutTimestamp;
  @override
  String? get gateOutBy;
  @override
  String? get createdBy;
  @override
  int? get noOfLineItems;
  @override
  String? get remark;
  @override
  String? get countSheetNo;

  /// Create a copy of GateEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GateEntryImplCopyWith<_$GateEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
