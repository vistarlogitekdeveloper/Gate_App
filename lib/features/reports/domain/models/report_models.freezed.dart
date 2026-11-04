// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReportFilter _$ReportFilterFromJson(Map<String, dynamic> json) {
  return _ReportFilter.fromJson(json);
}

/// @nodoc
mixin _$ReportFilter {
  DateTime? get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  String? get vendorFilter => throw _privateConstructorUsedError;
  String? get poFilter => throw _privateConstructorUsedError;

  /// Serializes this ReportFilter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReportFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportFilterCopyWith<ReportFilter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportFilterCopyWith<$Res> {
  factory $ReportFilterCopyWith(
          ReportFilter value, $Res Function(ReportFilter) then) =
      _$ReportFilterCopyWithImpl<$Res, ReportFilter>;
  @useResult
  $Res call(
      {DateTime? startDate,
      DateTime? endDate,
      String? vendorFilter,
      String? poFilter});
}

/// @nodoc
class _$ReportFilterCopyWithImpl<$Res, $Val extends ReportFilter>
    implements $ReportFilterCopyWith<$Res> {
  _$ReportFilterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? vendorFilter = freezed,
    Object? poFilter = freezed,
  }) {
    return _then(_value.copyWith(
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      vendorFilter: freezed == vendorFilter
          ? _value.vendorFilter
          : vendorFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      poFilter: freezed == poFilter
          ? _value.poFilter
          : poFilter // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReportFilterImplCopyWith<$Res>
    implements $ReportFilterCopyWith<$Res> {
  factory _$$ReportFilterImplCopyWith(
          _$ReportFilterImpl value, $Res Function(_$ReportFilterImpl) then) =
      __$$ReportFilterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime? startDate,
      DateTime? endDate,
      String? vendorFilter,
      String? poFilter});
}

/// @nodoc
class __$$ReportFilterImplCopyWithImpl<$Res>
    extends _$ReportFilterCopyWithImpl<$Res, _$ReportFilterImpl>
    implements _$$ReportFilterImplCopyWith<$Res> {
  __$$ReportFilterImplCopyWithImpl(
      _$ReportFilterImpl _value, $Res Function(_$ReportFilterImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReportFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? vendorFilter = freezed,
    Object? poFilter = freezed,
  }) {
    return _then(_$ReportFilterImpl(
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      vendorFilter: freezed == vendorFilter
          ? _value.vendorFilter
          : vendorFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      poFilter: freezed == poFilter
          ? _value.poFilter
          : poFilter // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReportFilterImpl implements _ReportFilter {
  const _$ReportFilterImpl(
      {this.startDate, this.endDate, this.vendorFilter, this.poFilter});

  factory _$ReportFilterImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReportFilterImplFromJson(json);

  @override
  final DateTime? startDate;
  @override
  final DateTime? endDate;
  @override
  final String? vendorFilter;
  @override
  final String? poFilter;

  @override
  String toString() {
    return 'ReportFilter(startDate: $startDate, endDate: $endDate, vendorFilter: $vendorFilter, poFilter: $poFilter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportFilterImpl &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.vendorFilter, vendorFilter) ||
                other.vendorFilter == vendorFilter) &&
            (identical(other.poFilter, poFilter) ||
                other.poFilter == poFilter));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, startDate, endDate, vendorFilter, poFilter);

  /// Create a copy of ReportFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportFilterImplCopyWith<_$ReportFilterImpl> get copyWith =>
      __$$ReportFilterImplCopyWithImpl<_$ReportFilterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReportFilterImplToJson(
      this,
    );
  }
}

abstract class _ReportFilter implements ReportFilter {
  const factory _ReportFilter(
      {final DateTime? startDate,
      final DateTime? endDate,
      final String? vendorFilter,
      final String? poFilter}) = _$ReportFilterImpl;

  factory _ReportFilter.fromJson(Map<String, dynamic> json) =
      _$ReportFilterImpl.fromJson;

  @override
  DateTime? get startDate;
  @override
  DateTime? get endDate;
  @override
  String? get vendorFilter;
  @override
  String? get poFilter;

  /// Create a copy of ReportFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportFilterImplCopyWith<_$ReportFilterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GateEntryReportItem _$GateEntryReportItemFromJson(Map<String, dynamic> json) {
  return _GateEntryReportItem.fromJson(json);
}

/// @nodoc
mixin _$GateEntryReportItem {
  String get gateEntryNo => throw _privateConstructorUsedError;
  String get direction => throw _privateConstructorUsedError;
  String get challanNo => throw _privateConstructorUsedError;
  String get lrNo => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  DateTime? get gateOutDate => throw _privateConstructorUsedError;
  String get material => throw _privateConstructorUsedError;
  int get qty => throw _privateConstructorUsedError;
  String get vendor => throw _privateConstructorUsedError;
  String get vendorCode => throw _privateConstructorUsedError;
  String get transporter => throw _privateConstructorUsedError;
  String get vehicleNo => throw _privateConstructorUsedError;
  String get poNumber => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get countSheetNo => throw _privateConstructorUsedError;

  /// Serializes this GateEntryReportItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GateEntryReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GateEntryReportItemCopyWith<GateEntryReportItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GateEntryReportItemCopyWith<$Res> {
  factory $GateEntryReportItemCopyWith(
          GateEntryReportItem value, $Res Function(GateEntryReportItem) then) =
      _$GateEntryReportItemCopyWithImpl<$Res, GateEntryReportItem>;
  @useResult
  $Res call(
      {String gateEntryNo,
      String direction,
      String challanNo,
      String lrNo,
      DateTime date,
      DateTime? gateOutDate,
      String material,
      int qty,
      String vendor,
      String vendorCode,
      String transporter,
      String vehicleNo,
      String poNumber,
      String status,
      String? countSheetNo});
}

/// @nodoc
class _$GateEntryReportItemCopyWithImpl<$Res, $Val extends GateEntryReportItem>
    implements $GateEntryReportItemCopyWith<$Res> {
  _$GateEntryReportItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GateEntryReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = null,
    Object? direction = null,
    Object? challanNo = null,
    Object? lrNo = null,
    Object? date = null,
    Object? gateOutDate = freezed,
    Object? material = null,
    Object? qty = null,
    Object? vendor = null,
    Object? vendorCode = null,
    Object? transporter = null,
    Object? vehicleNo = null,
    Object? poNumber = null,
    Object? status = null,
    Object? countSheetNo = freezed,
  }) {
    return _then(_value.copyWith(
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as String,
      challanNo: null == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String,
      lrNo: null == lrNo
          ? _value.lrNo
          : lrNo // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      gateOutDate: freezed == gateOutDate
          ? _value.gateOutDate
          : gateOutDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      material: null == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String,
      qty: null == qty
          ? _value.qty
          : qty // ignore: cast_nullable_to_non_nullable
              as int,
      vendor: null == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String,
      vendorCode: null == vendorCode
          ? _value.vendorCode
          : vendorCode // ignore: cast_nullable_to_non_nullable
              as String,
      transporter: null == transporter
          ? _value.transporter
          : transporter // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleNo: null == vehicleNo
          ? _value.vehicleNo
          : vehicleNo // ignore: cast_nullable_to_non_nullable
              as String,
      poNumber: null == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      countSheetNo: freezed == countSheetNo
          ? _value.countSheetNo
          : countSheetNo // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GateEntryReportItemImplCopyWith<$Res>
    implements $GateEntryReportItemCopyWith<$Res> {
  factory _$$GateEntryReportItemImplCopyWith(_$GateEntryReportItemImpl value,
          $Res Function(_$GateEntryReportItemImpl) then) =
      __$$GateEntryReportItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String gateEntryNo,
      String direction,
      String challanNo,
      String lrNo,
      DateTime date,
      DateTime? gateOutDate,
      String material,
      int qty,
      String vendor,
      String vendorCode,
      String transporter,
      String vehicleNo,
      String poNumber,
      String status,
      String? countSheetNo});
}

/// @nodoc
class __$$GateEntryReportItemImplCopyWithImpl<$Res>
    extends _$GateEntryReportItemCopyWithImpl<$Res, _$GateEntryReportItemImpl>
    implements _$$GateEntryReportItemImplCopyWith<$Res> {
  __$$GateEntryReportItemImplCopyWithImpl(_$GateEntryReportItemImpl _value,
      $Res Function(_$GateEntryReportItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of GateEntryReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = null,
    Object? direction = null,
    Object? challanNo = null,
    Object? lrNo = null,
    Object? date = null,
    Object? gateOutDate = freezed,
    Object? material = null,
    Object? qty = null,
    Object? vendor = null,
    Object? vendorCode = null,
    Object? transporter = null,
    Object? vehicleNo = null,
    Object? poNumber = null,
    Object? status = null,
    Object? countSheetNo = freezed,
  }) {
    return _then(_$GateEntryReportItemImpl(
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as String,
      challanNo: null == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String,
      lrNo: null == lrNo
          ? _value.lrNo
          : lrNo // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      gateOutDate: freezed == gateOutDate
          ? _value.gateOutDate
          : gateOutDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      material: null == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String,
      qty: null == qty
          ? _value.qty
          : qty // ignore: cast_nullable_to_non_nullable
              as int,
      vendor: null == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String,
      vendorCode: null == vendorCode
          ? _value.vendorCode
          : vendorCode // ignore: cast_nullable_to_non_nullable
              as String,
      transporter: null == transporter
          ? _value.transporter
          : transporter // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleNo: null == vehicleNo
          ? _value.vehicleNo
          : vehicleNo // ignore: cast_nullable_to_non_nullable
              as String,
      poNumber: null == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      countSheetNo: freezed == countSheetNo
          ? _value.countSheetNo
          : countSheetNo // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GateEntryReportItemImpl implements _GateEntryReportItem {
  const _$GateEntryReportItemImpl(
      {required this.gateEntryNo,
      required this.direction,
      required this.challanNo,
      required this.lrNo,
      required this.date,
      this.gateOutDate,
      required this.material,
      required this.qty,
      required this.vendor,
      required this.vendorCode,
      required this.transporter,
      required this.vehicleNo,
      required this.poNumber,
      required this.status,
      this.countSheetNo});

  factory _$GateEntryReportItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$GateEntryReportItemImplFromJson(json);

  @override
  final String gateEntryNo;
  @override
  final String direction;
  @override
  final String challanNo;
  @override
  final String lrNo;
  @override
  final DateTime date;
  @override
  final DateTime? gateOutDate;
  @override
  final String material;
  @override
  final int qty;
  @override
  final String vendor;
  @override
  final String vendorCode;
  @override
  final String transporter;
  @override
  final String vehicleNo;
  @override
  final String poNumber;
  @override
  final String status;
  @override
  final String? countSheetNo;

  @override
  String toString() {
    return 'GateEntryReportItem(gateEntryNo: $gateEntryNo, direction: $direction, challanNo: $challanNo, lrNo: $lrNo, date: $date, gateOutDate: $gateOutDate, material: $material, qty: $qty, vendor: $vendor, vendorCode: $vendorCode, transporter: $transporter, vehicleNo: $vehicleNo, poNumber: $poNumber, status: $status, countSheetNo: $countSheetNo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GateEntryReportItemImpl &&
            (identical(other.gateEntryNo, gateEntryNo) ||
                other.gateEntryNo == gateEntryNo) &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.challanNo, challanNo) ||
                other.challanNo == challanNo) &&
            (identical(other.lrNo, lrNo) || other.lrNo == lrNo) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.gateOutDate, gateOutDate) ||
                other.gateOutDate == gateOutDate) &&
            (identical(other.material, material) ||
                other.material == material) &&
            (identical(other.qty, qty) || other.qty == qty) &&
            (identical(other.vendor, vendor) || other.vendor == vendor) &&
            (identical(other.vendorCode, vendorCode) ||
                other.vendorCode == vendorCode) &&
            (identical(other.transporter, transporter) ||
                other.transporter == transporter) &&
            (identical(other.vehicleNo, vehicleNo) ||
                other.vehicleNo == vehicleNo) &&
            (identical(other.poNumber, poNumber) ||
                other.poNumber == poNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.countSheetNo, countSheetNo) ||
                other.countSheetNo == countSheetNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      gateEntryNo,
      direction,
      challanNo,
      lrNo,
      date,
      gateOutDate,
      material,
      qty,
      vendor,
      vendorCode,
      transporter,
      vehicleNo,
      poNumber,
      status,
      countSheetNo);

  /// Create a copy of GateEntryReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GateEntryReportItemImplCopyWith<_$GateEntryReportItemImpl> get copyWith =>
      __$$GateEntryReportItemImplCopyWithImpl<_$GateEntryReportItemImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GateEntryReportItemImplToJson(
      this,
    );
  }
}

abstract class _GateEntryReportItem implements GateEntryReportItem {
  const factory _GateEntryReportItem(
      {required final String gateEntryNo,
      required final String direction,
      required final String challanNo,
      required final String lrNo,
      required final DateTime date,
      final DateTime? gateOutDate,
      required final String material,
      required final int qty,
      required final String vendor,
      required final String vendorCode,
      required final String transporter,
      required final String vehicleNo,
      required final String poNumber,
      required final String status,
      final String? countSheetNo}) = _$GateEntryReportItemImpl;

  factory _GateEntryReportItem.fromJson(Map<String, dynamic> json) =
      _$GateEntryReportItemImpl.fromJson;

  @override
  String get gateEntryNo;
  @override
  String get direction;
  @override
  String get challanNo;
  @override
  String get lrNo;
  @override
  DateTime get date;
  @override
  DateTime? get gateOutDate;
  @override
  String get material;
  @override
  int get qty;
  @override
  String get vendor;
  @override
  String get vendorCode;
  @override
  String get transporter;
  @override
  String get vehicleNo;
  @override
  String get poNumber;
  @override
  String get status;
  @override
  String? get countSheetNo;

  /// Create a copy of GateEntryReportItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GateEntryReportItemImplCopyWith<_$GateEntryReportItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GrnReconReportItem {
  @JsonKey(name: 'gate_entry_no')
  String? get gateEntryNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'grn_no')
  String? get grnNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'po_number')
  String? get poNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'challan_no')
  String? get challanNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'matched_status')
  String? get matchedStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'quantity_diff')
  double? get quantityDiff => throw _privateConstructorUsedError;
  @JsonKey(name: 'vendor_name')
  String? get vendorName => throw _privateConstructorUsedError;
  @JsonKey(name: 'reconciled_at')
  String? get reconciledAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'sr_no')
  String? get srNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'remarks')
  String? get remarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'duplicate_reference')
  String? get duplicateReference => throw _privateConstructorUsedError;
  @JsonKey(name: 'dublicate')
  String? get dublicate => throw _privateConstructorUsedError;
  @JsonKey(name: 'reference_no')
  String? get referenceNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'reference')
  String? get reference => throw _privateConstructorUsedError;
  @JsonKey(name: 'document_date')
  String? get documentDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'quantity')
  String? get quantity => throw _privateConstructorUsedError;
  @JsonKey(name: 'material')
  String? get material => throw _privateConstructorUsedError;
  @JsonKey(name: 'material_document')
  String? get materialDocument => throw _privateConstructorUsedError;
  @JsonKey(name: 'posting_date')
  String? get postingDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'plant')
  String? get plant => throw _privateConstructorUsedError;
  @JsonKey(name: 'material_description')
  String? get materialDescription => throw _privateConstructorUsedError;
  @JsonKey(name: 'movement_type')
  String? get movementType => throw _privateConstructorUsedError;
  @JsonKey(name: 'movement_type_text')
  String? get movementTypeText => throw _privateConstructorUsedError;
  @JsonKey(name: 'supplier')
  String? get supplier => throw _privateConstructorUsedError;
  @JsonKey(name: 'purchase_order')
  String? get purchaseOrder => throw _privateConstructorUsedError;
  @JsonKey(name: 'document_header_text')
  String? get documentHeaderText => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_name')
  String? get userName => throw _privateConstructorUsedError;
  @JsonKey(name: 'entry_date')
  String? get entryDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'time_of_entry')
  String? get timeOfEntry => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_in_local_currency')
  String? get amountInLocalCurrency => throw _privateConstructorUsedError;
  @JsonKey(name: 'qty_in_opun')
  String? get qtyInOpun => throw _privateConstructorUsedError;
  @JsonKey(name: 'qty_in_order_unit')
  String? get qtyInOrderUnit => throw _privateConstructorUsedError;
  @JsonKey(name: 'local_time')
  String? get localTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'local_date')
  String? get localDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'shift')
  String? get shift => throw _privateConstructorUsedError;
  @JsonKey(name: 'store_remarks')
  String? get storeRemarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'status')
  String? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'aging')
  String? get aging => throw _privateConstructorUsedError;
  @JsonKey(name: 'mdr')
  String? get mdr => throw _privateConstructorUsedError;
  @JsonKey(name: 'scanning_invoice_status')
  String? get scanningInvoiceStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'scanning_date')
  String? get scanningDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'vendor')
  String? get vendor => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_vendor_name')
  String? get sourceVendorName => throw _privateConstructorUsedError;
  @JsonKey(name: 'buyer_name')
  String? get buyerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'maker_checker')
  String? get makerChecker => throw _privateConstructorUsedError;

  /// Create a copy of GrnReconReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GrnReconReportItemCopyWith<GrnReconReportItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GrnReconReportItemCopyWith<$Res> {
  factory $GrnReconReportItemCopyWith(
          GrnReconReportItem value, $Res Function(GrnReconReportItem) then) =
      _$GrnReconReportItemCopyWithImpl<$Res, GrnReconReportItem>;
  @useResult
  $Res call(
      {@JsonKey(name: 'gate_entry_no') String? gateEntryNo,
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
      @JsonKey(name: 'maker_checker') String? makerChecker});
}

/// @nodoc
class _$GrnReconReportItemCopyWithImpl<$Res, $Val extends GrnReconReportItem>
    implements $GrnReconReportItemCopyWith<$Res> {
  _$GrnReconReportItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GrnReconReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = freezed,
    Object? grnNo = freezed,
    Object? poNumber = freezed,
    Object? challanNo = freezed,
    Object? matchedStatus = freezed,
    Object? quantityDiff = freezed,
    Object? vendorName = freezed,
    Object? reconciledAt = freezed,
    Object? srNo = freezed,
    Object? remarks = freezed,
    Object? duplicateReference = freezed,
    Object? dublicate = freezed,
    Object? referenceNo = freezed,
    Object? reference = freezed,
    Object? documentDate = freezed,
    Object? quantity = freezed,
    Object? material = freezed,
    Object? materialDocument = freezed,
    Object? postingDate = freezed,
    Object? plant = freezed,
    Object? materialDescription = freezed,
    Object? movementType = freezed,
    Object? movementTypeText = freezed,
    Object? supplier = freezed,
    Object? purchaseOrder = freezed,
    Object? documentHeaderText = freezed,
    Object? userName = freezed,
    Object? entryDate = freezed,
    Object? timeOfEntry = freezed,
    Object? amountInLocalCurrency = freezed,
    Object? qtyInOpun = freezed,
    Object? qtyInOrderUnit = freezed,
    Object? localTime = freezed,
    Object? localDate = freezed,
    Object? shift = freezed,
    Object? storeRemarks = freezed,
    Object? status = freezed,
    Object? aging = freezed,
    Object? mdr = freezed,
    Object? scanningInvoiceStatus = freezed,
    Object? scanningDate = freezed,
    Object? vendor = freezed,
    Object? sourceVendorName = freezed,
    Object? buyerName = freezed,
    Object? makerChecker = freezed,
  }) {
    return _then(_value.copyWith(
      gateEntryNo: freezed == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String?,
      grnNo: freezed == grnNo
          ? _value.grnNo
          : grnNo // ignore: cast_nullable_to_non_nullable
              as String?,
      poNumber: freezed == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      challanNo: freezed == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String?,
      matchedStatus: freezed == matchedStatus
          ? _value.matchedStatus
          : matchedStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      quantityDiff: freezed == quantityDiff
          ? _value.quantityDiff
          : quantityDiff // ignore: cast_nullable_to_non_nullable
              as double?,
      vendorName: freezed == vendorName
          ? _value.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      reconciledAt: freezed == reconciledAt
          ? _value.reconciledAt
          : reconciledAt // ignore: cast_nullable_to_non_nullable
              as String?,
      srNo: freezed == srNo
          ? _value.srNo
          : srNo // ignore: cast_nullable_to_non_nullable
              as String?,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      duplicateReference: freezed == duplicateReference
          ? _value.duplicateReference
          : duplicateReference // ignore: cast_nullable_to_non_nullable
              as String?,
      dublicate: freezed == dublicate
          ? _value.dublicate
          : dublicate // ignore: cast_nullable_to_non_nullable
              as String?,
      referenceNo: freezed == referenceNo
          ? _value.referenceNo
          : referenceNo // ignore: cast_nullable_to_non_nullable
              as String?,
      reference: freezed == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String?,
      documentDate: freezed == documentDate
          ? _value.documentDate
          : documentDate // ignore: cast_nullable_to_non_nullable
              as String?,
      quantity: freezed == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as String?,
      material: freezed == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String?,
      materialDocument: freezed == materialDocument
          ? _value.materialDocument
          : materialDocument // ignore: cast_nullable_to_non_nullable
              as String?,
      postingDate: freezed == postingDate
          ? _value.postingDate
          : postingDate // ignore: cast_nullable_to_non_nullable
              as String?,
      plant: freezed == plant
          ? _value.plant
          : plant // ignore: cast_nullable_to_non_nullable
              as String?,
      materialDescription: freezed == materialDescription
          ? _value.materialDescription
          : materialDescription // ignore: cast_nullable_to_non_nullable
              as String?,
      movementType: freezed == movementType
          ? _value.movementType
          : movementType // ignore: cast_nullable_to_non_nullable
              as String?,
      movementTypeText: freezed == movementTypeText
          ? _value.movementTypeText
          : movementTypeText // ignore: cast_nullable_to_non_nullable
              as String?,
      supplier: freezed == supplier
          ? _value.supplier
          : supplier // ignore: cast_nullable_to_non_nullable
              as String?,
      purchaseOrder: freezed == purchaseOrder
          ? _value.purchaseOrder
          : purchaseOrder // ignore: cast_nullable_to_non_nullable
              as String?,
      documentHeaderText: freezed == documentHeaderText
          ? _value.documentHeaderText
          : documentHeaderText // ignore: cast_nullable_to_non_nullable
              as String?,
      userName: freezed == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String?,
      entryDate: freezed == entryDate
          ? _value.entryDate
          : entryDate // ignore: cast_nullable_to_non_nullable
              as String?,
      timeOfEntry: freezed == timeOfEntry
          ? _value.timeOfEntry
          : timeOfEntry // ignore: cast_nullable_to_non_nullable
              as String?,
      amountInLocalCurrency: freezed == amountInLocalCurrency
          ? _value.amountInLocalCurrency
          : amountInLocalCurrency // ignore: cast_nullable_to_non_nullable
              as String?,
      qtyInOpun: freezed == qtyInOpun
          ? _value.qtyInOpun
          : qtyInOpun // ignore: cast_nullable_to_non_nullable
              as String?,
      qtyInOrderUnit: freezed == qtyInOrderUnit
          ? _value.qtyInOrderUnit
          : qtyInOrderUnit // ignore: cast_nullable_to_non_nullable
              as String?,
      localTime: freezed == localTime
          ? _value.localTime
          : localTime // ignore: cast_nullable_to_non_nullable
              as String?,
      localDate: freezed == localDate
          ? _value.localDate
          : localDate // ignore: cast_nullable_to_non_nullable
              as String?,
      shift: freezed == shift
          ? _value.shift
          : shift // ignore: cast_nullable_to_non_nullable
              as String?,
      storeRemarks: freezed == storeRemarks
          ? _value.storeRemarks
          : storeRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      aging: freezed == aging
          ? _value.aging
          : aging // ignore: cast_nullable_to_non_nullable
              as String?,
      mdr: freezed == mdr
          ? _value.mdr
          : mdr // ignore: cast_nullable_to_non_nullable
              as String?,
      scanningInvoiceStatus: freezed == scanningInvoiceStatus
          ? _value.scanningInvoiceStatus
          : scanningInvoiceStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      scanningDate: freezed == scanningDate
          ? _value.scanningDate
          : scanningDate // ignore: cast_nullable_to_non_nullable
              as String?,
      vendor: freezed == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceVendorName: freezed == sourceVendorName
          ? _value.sourceVendorName
          : sourceVendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      buyerName: freezed == buyerName
          ? _value.buyerName
          : buyerName // ignore: cast_nullable_to_non_nullable
              as String?,
      makerChecker: freezed == makerChecker
          ? _value.makerChecker
          : makerChecker // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GrnReconReportItemImplCopyWith<$Res>
    implements $GrnReconReportItemCopyWith<$Res> {
  factory _$$GrnReconReportItemImplCopyWith(_$GrnReconReportItemImpl value,
          $Res Function(_$GrnReconReportItemImpl) then) =
      __$$GrnReconReportItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'gate_entry_no') String? gateEntryNo,
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
      @JsonKey(name: 'maker_checker') String? makerChecker});
}

/// @nodoc
class __$$GrnReconReportItemImplCopyWithImpl<$Res>
    extends _$GrnReconReportItemCopyWithImpl<$Res, _$GrnReconReportItemImpl>
    implements _$$GrnReconReportItemImplCopyWith<$Res> {
  __$$GrnReconReportItemImplCopyWithImpl(_$GrnReconReportItemImpl _value,
      $Res Function(_$GrnReconReportItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrnReconReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = freezed,
    Object? grnNo = freezed,
    Object? poNumber = freezed,
    Object? challanNo = freezed,
    Object? matchedStatus = freezed,
    Object? quantityDiff = freezed,
    Object? vendorName = freezed,
    Object? reconciledAt = freezed,
    Object? srNo = freezed,
    Object? remarks = freezed,
    Object? duplicateReference = freezed,
    Object? dublicate = freezed,
    Object? referenceNo = freezed,
    Object? reference = freezed,
    Object? documentDate = freezed,
    Object? quantity = freezed,
    Object? material = freezed,
    Object? materialDocument = freezed,
    Object? postingDate = freezed,
    Object? plant = freezed,
    Object? materialDescription = freezed,
    Object? movementType = freezed,
    Object? movementTypeText = freezed,
    Object? supplier = freezed,
    Object? purchaseOrder = freezed,
    Object? documentHeaderText = freezed,
    Object? userName = freezed,
    Object? entryDate = freezed,
    Object? timeOfEntry = freezed,
    Object? amountInLocalCurrency = freezed,
    Object? qtyInOpun = freezed,
    Object? qtyInOrderUnit = freezed,
    Object? localTime = freezed,
    Object? localDate = freezed,
    Object? shift = freezed,
    Object? storeRemarks = freezed,
    Object? status = freezed,
    Object? aging = freezed,
    Object? mdr = freezed,
    Object? scanningInvoiceStatus = freezed,
    Object? scanningDate = freezed,
    Object? vendor = freezed,
    Object? sourceVendorName = freezed,
    Object? buyerName = freezed,
    Object? makerChecker = freezed,
  }) {
    return _then(_$GrnReconReportItemImpl(
      gateEntryNo: freezed == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String?,
      grnNo: freezed == grnNo
          ? _value.grnNo
          : grnNo // ignore: cast_nullable_to_non_nullable
              as String?,
      poNumber: freezed == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      challanNo: freezed == challanNo
          ? _value.challanNo
          : challanNo // ignore: cast_nullable_to_non_nullable
              as String?,
      matchedStatus: freezed == matchedStatus
          ? _value.matchedStatus
          : matchedStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      quantityDiff: freezed == quantityDiff
          ? _value.quantityDiff
          : quantityDiff // ignore: cast_nullable_to_non_nullable
              as double?,
      vendorName: freezed == vendorName
          ? _value.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      reconciledAt: freezed == reconciledAt
          ? _value.reconciledAt
          : reconciledAt // ignore: cast_nullable_to_non_nullable
              as String?,
      srNo: freezed == srNo
          ? _value.srNo
          : srNo // ignore: cast_nullable_to_non_nullable
              as String?,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      duplicateReference: freezed == duplicateReference
          ? _value.duplicateReference
          : duplicateReference // ignore: cast_nullable_to_non_nullable
              as String?,
      dublicate: freezed == dublicate
          ? _value.dublicate
          : dublicate // ignore: cast_nullable_to_non_nullable
              as String?,
      referenceNo: freezed == referenceNo
          ? _value.referenceNo
          : referenceNo // ignore: cast_nullable_to_non_nullable
              as String?,
      reference: freezed == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String?,
      documentDate: freezed == documentDate
          ? _value.documentDate
          : documentDate // ignore: cast_nullable_to_non_nullable
              as String?,
      quantity: freezed == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as String?,
      material: freezed == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String?,
      materialDocument: freezed == materialDocument
          ? _value.materialDocument
          : materialDocument // ignore: cast_nullable_to_non_nullable
              as String?,
      postingDate: freezed == postingDate
          ? _value.postingDate
          : postingDate // ignore: cast_nullable_to_non_nullable
              as String?,
      plant: freezed == plant
          ? _value.plant
          : plant // ignore: cast_nullable_to_non_nullable
              as String?,
      materialDescription: freezed == materialDescription
          ? _value.materialDescription
          : materialDescription // ignore: cast_nullable_to_non_nullable
              as String?,
      movementType: freezed == movementType
          ? _value.movementType
          : movementType // ignore: cast_nullable_to_non_nullable
              as String?,
      movementTypeText: freezed == movementTypeText
          ? _value.movementTypeText
          : movementTypeText // ignore: cast_nullable_to_non_nullable
              as String?,
      supplier: freezed == supplier
          ? _value.supplier
          : supplier // ignore: cast_nullable_to_non_nullable
              as String?,
      purchaseOrder: freezed == purchaseOrder
          ? _value.purchaseOrder
          : purchaseOrder // ignore: cast_nullable_to_non_nullable
              as String?,
      documentHeaderText: freezed == documentHeaderText
          ? _value.documentHeaderText
          : documentHeaderText // ignore: cast_nullable_to_non_nullable
              as String?,
      userName: freezed == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String?,
      entryDate: freezed == entryDate
          ? _value.entryDate
          : entryDate // ignore: cast_nullable_to_non_nullable
              as String?,
      timeOfEntry: freezed == timeOfEntry
          ? _value.timeOfEntry
          : timeOfEntry // ignore: cast_nullable_to_non_nullable
              as String?,
      amountInLocalCurrency: freezed == amountInLocalCurrency
          ? _value.amountInLocalCurrency
          : amountInLocalCurrency // ignore: cast_nullable_to_non_nullable
              as String?,
      qtyInOpun: freezed == qtyInOpun
          ? _value.qtyInOpun
          : qtyInOpun // ignore: cast_nullable_to_non_nullable
              as String?,
      qtyInOrderUnit: freezed == qtyInOrderUnit
          ? _value.qtyInOrderUnit
          : qtyInOrderUnit // ignore: cast_nullable_to_non_nullable
              as String?,
      localTime: freezed == localTime
          ? _value.localTime
          : localTime // ignore: cast_nullable_to_non_nullable
              as String?,
      localDate: freezed == localDate
          ? _value.localDate
          : localDate // ignore: cast_nullable_to_non_nullable
              as String?,
      shift: freezed == shift
          ? _value.shift
          : shift // ignore: cast_nullable_to_non_nullable
              as String?,
      storeRemarks: freezed == storeRemarks
          ? _value.storeRemarks
          : storeRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      aging: freezed == aging
          ? _value.aging
          : aging // ignore: cast_nullable_to_non_nullable
              as String?,
      mdr: freezed == mdr
          ? _value.mdr
          : mdr // ignore: cast_nullable_to_non_nullable
              as String?,
      scanningInvoiceStatus: freezed == scanningInvoiceStatus
          ? _value.scanningInvoiceStatus
          : scanningInvoiceStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      scanningDate: freezed == scanningDate
          ? _value.scanningDate
          : scanningDate // ignore: cast_nullable_to_non_nullable
              as String?,
      vendor: freezed == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceVendorName: freezed == sourceVendorName
          ? _value.sourceVendorName
          : sourceVendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      buyerName: freezed == buyerName
          ? _value.buyerName
          : buyerName // ignore: cast_nullable_to_non_nullable
              as String?,
      makerChecker: freezed == makerChecker
          ? _value.makerChecker
          : makerChecker // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

@JsonSerializable(createToJson: false)
class _$GrnReconReportItemImpl implements _GrnReconReportItem {
  const _$GrnReconReportItemImpl(
      {@JsonKey(name: 'gate_entry_no') this.gateEntryNo,
      @JsonKey(name: 'grn_no') this.grnNo,
      @JsonKey(name: 'po_number') this.poNumber,
      @JsonKey(name: 'challan_no') this.challanNo,
      @JsonKey(name: 'matched_status') this.matchedStatus,
      @JsonKey(name: 'quantity_diff') this.quantityDiff,
      @JsonKey(name: 'vendor_name') this.vendorName,
      @JsonKey(name: 'reconciled_at') this.reconciledAt,
      @JsonKey(name: 'sr_no') this.srNo,
      @JsonKey(name: 'remarks') this.remarks,
      @JsonKey(name: 'duplicate_reference') this.duplicateReference,
      @JsonKey(name: 'dublicate') this.dublicate,
      @JsonKey(name: 'reference_no') this.referenceNo,
      @JsonKey(name: 'reference') this.reference,
      @JsonKey(name: 'document_date') this.documentDate,
      @JsonKey(name: 'quantity') this.quantity,
      @JsonKey(name: 'material') this.material,
      @JsonKey(name: 'material_document') this.materialDocument,
      @JsonKey(name: 'posting_date') this.postingDate,
      @JsonKey(name: 'plant') this.plant,
      @JsonKey(name: 'material_description') this.materialDescription,
      @JsonKey(name: 'movement_type') this.movementType,
      @JsonKey(name: 'movement_type_text') this.movementTypeText,
      @JsonKey(name: 'supplier') this.supplier,
      @JsonKey(name: 'purchase_order') this.purchaseOrder,
      @JsonKey(name: 'document_header_text') this.documentHeaderText,
      @JsonKey(name: 'user_name') this.userName,
      @JsonKey(name: 'entry_date') this.entryDate,
      @JsonKey(name: 'time_of_entry') this.timeOfEntry,
      @JsonKey(name: 'amount_in_local_currency') this.amountInLocalCurrency,
      @JsonKey(name: 'qty_in_opun') this.qtyInOpun,
      @JsonKey(name: 'qty_in_order_unit') this.qtyInOrderUnit,
      @JsonKey(name: 'local_time') this.localTime,
      @JsonKey(name: 'local_date') this.localDate,
      @JsonKey(name: 'shift') this.shift,
      @JsonKey(name: 'store_remarks') this.storeRemarks,
      @JsonKey(name: 'status') this.status,
      @JsonKey(name: 'aging') this.aging,
      @JsonKey(name: 'mdr') this.mdr,
      @JsonKey(name: 'scanning_invoice_status') this.scanningInvoiceStatus,
      @JsonKey(name: 'scanning_date') this.scanningDate,
      @JsonKey(name: 'vendor') this.vendor,
      @JsonKey(name: 'source_vendor_name') this.sourceVendorName,
      @JsonKey(name: 'buyer_name') this.buyerName,
      @JsonKey(name: 'maker_checker') this.makerChecker});

  @override
  @JsonKey(name: 'gate_entry_no')
  final String? gateEntryNo;
  @override
  @JsonKey(name: 'grn_no')
  final String? grnNo;
  @override
  @JsonKey(name: 'po_number')
  final String? poNumber;
  @override
  @JsonKey(name: 'challan_no')
  final String? challanNo;
  @override
  @JsonKey(name: 'matched_status')
  final String? matchedStatus;
  @override
  @JsonKey(name: 'quantity_diff')
  final double? quantityDiff;
  @override
  @JsonKey(name: 'vendor_name')
  final String? vendorName;
  @override
  @JsonKey(name: 'reconciled_at')
  final String? reconciledAt;
  @override
  @JsonKey(name: 'sr_no')
  final String? srNo;
  @override
  @JsonKey(name: 'remarks')
  final String? remarks;
  @override
  @JsonKey(name: 'duplicate_reference')
  final String? duplicateReference;
  @override
  @JsonKey(name: 'dublicate')
  final String? dublicate;
  @override
  @JsonKey(name: 'reference_no')
  final String? referenceNo;
  @override
  @JsonKey(name: 'reference')
  final String? reference;
  @override
  @JsonKey(name: 'document_date')
  final String? documentDate;
  @override
  @JsonKey(name: 'quantity')
  final String? quantity;
  @override
  @JsonKey(name: 'material')
  final String? material;
  @override
  @JsonKey(name: 'material_document')
  final String? materialDocument;
  @override
  @JsonKey(name: 'posting_date')
  final String? postingDate;
  @override
  @JsonKey(name: 'plant')
  final String? plant;
  @override
  @JsonKey(name: 'material_description')
  final String? materialDescription;
  @override
  @JsonKey(name: 'movement_type')
  final String? movementType;
  @override
  @JsonKey(name: 'movement_type_text')
  final String? movementTypeText;
  @override
  @JsonKey(name: 'supplier')
  final String? supplier;
  @override
  @JsonKey(name: 'purchase_order')
  final String? purchaseOrder;
  @override
  @JsonKey(name: 'document_header_text')
  final String? documentHeaderText;
  @override
  @JsonKey(name: 'user_name')
  final String? userName;
  @override
  @JsonKey(name: 'entry_date')
  final String? entryDate;
  @override
  @JsonKey(name: 'time_of_entry')
  final String? timeOfEntry;
  @override
  @JsonKey(name: 'amount_in_local_currency')
  final String? amountInLocalCurrency;
  @override
  @JsonKey(name: 'qty_in_opun')
  final String? qtyInOpun;
  @override
  @JsonKey(name: 'qty_in_order_unit')
  final String? qtyInOrderUnit;
  @override
  @JsonKey(name: 'local_time')
  final String? localTime;
  @override
  @JsonKey(name: 'local_date')
  final String? localDate;
  @override
  @JsonKey(name: 'shift')
  final String? shift;
  @override
  @JsonKey(name: 'store_remarks')
  final String? storeRemarks;
  @override
  @JsonKey(name: 'status')
  final String? status;
  @override
  @JsonKey(name: 'aging')
  final String? aging;
  @override
  @JsonKey(name: 'mdr')
  final String? mdr;
  @override
  @JsonKey(name: 'scanning_invoice_status')
  final String? scanningInvoiceStatus;
  @override
  @JsonKey(name: 'scanning_date')
  final String? scanningDate;
  @override
  @JsonKey(name: 'vendor')
  final String? vendor;
  @override
  @JsonKey(name: 'source_vendor_name')
  final String? sourceVendorName;
  @override
  @JsonKey(name: 'buyer_name')
  final String? buyerName;
  @override
  @JsonKey(name: 'maker_checker')
  final String? makerChecker;

  @override
  String toString() {
    return 'GrnReconReportItem(gateEntryNo: $gateEntryNo, grnNo: $grnNo, poNumber: $poNumber, challanNo: $challanNo, matchedStatus: $matchedStatus, quantityDiff: $quantityDiff, vendorName: $vendorName, reconciledAt: $reconciledAt, srNo: $srNo, remarks: $remarks, duplicateReference: $duplicateReference, dublicate: $dublicate, referenceNo: $referenceNo, reference: $reference, documentDate: $documentDate, quantity: $quantity, material: $material, materialDocument: $materialDocument, postingDate: $postingDate, plant: $plant, materialDescription: $materialDescription, movementType: $movementType, movementTypeText: $movementTypeText, supplier: $supplier, purchaseOrder: $purchaseOrder, documentHeaderText: $documentHeaderText, userName: $userName, entryDate: $entryDate, timeOfEntry: $timeOfEntry, amountInLocalCurrency: $amountInLocalCurrency, qtyInOpun: $qtyInOpun, qtyInOrderUnit: $qtyInOrderUnit, localTime: $localTime, localDate: $localDate, shift: $shift, storeRemarks: $storeRemarks, status: $status, aging: $aging, mdr: $mdr, scanningInvoiceStatus: $scanningInvoiceStatus, scanningDate: $scanningDate, vendor: $vendor, sourceVendorName: $sourceVendorName, buyerName: $buyerName, makerChecker: $makerChecker)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GrnReconReportItemImpl &&
            (identical(other.gateEntryNo, gateEntryNo) ||
                other.gateEntryNo == gateEntryNo) &&
            (identical(other.grnNo, grnNo) || other.grnNo == grnNo) &&
            (identical(other.poNumber, poNumber) ||
                other.poNumber == poNumber) &&
            (identical(other.challanNo, challanNo) ||
                other.challanNo == challanNo) &&
            (identical(other.matchedStatus, matchedStatus) ||
                other.matchedStatus == matchedStatus) &&
            (identical(other.quantityDiff, quantityDiff) ||
                other.quantityDiff == quantityDiff) &&
            (identical(other.vendorName, vendorName) ||
                other.vendorName == vendorName) &&
            (identical(other.reconciledAt, reconciledAt) ||
                other.reconciledAt == reconciledAt) &&
            (identical(other.srNo, srNo) || other.srNo == srNo) &&
            (identical(other.remarks, remarks) || other.remarks == remarks) &&
            (identical(other.duplicateReference, duplicateReference) ||
                other.duplicateReference == duplicateReference) &&
            (identical(other.dublicate, dublicate) ||
                other.dublicate == dublicate) &&
            (identical(other.referenceNo, referenceNo) ||
                other.referenceNo == referenceNo) &&
            (identical(other.reference, reference) ||
                other.reference == reference) &&
            (identical(other.documentDate, documentDate) ||
                other.documentDate == documentDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.material, material) ||
                other.material == material) &&
            (identical(other.materialDocument, materialDocument) ||
                other.materialDocument == materialDocument) &&
            (identical(other.postingDate, postingDate) ||
                other.postingDate == postingDate) &&
            (identical(other.plant, plant) || other.plant == plant) &&
            (identical(other.materialDescription, materialDescription) ||
                other.materialDescription == materialDescription) &&
            (identical(other.movementType, movementType) ||
                other.movementType == movementType) &&
            (identical(other.movementTypeText, movementTypeText) ||
                other.movementTypeText == movementTypeText) &&
            (identical(other.supplier, supplier) ||
                other.supplier == supplier) &&
            (identical(other.purchaseOrder, purchaseOrder) ||
                other.purchaseOrder == purchaseOrder) &&
            (identical(other.documentHeaderText, documentHeaderText) ||
                other.documentHeaderText == documentHeaderText) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.entryDate, entryDate) ||
                other.entryDate == entryDate) &&
            (identical(other.timeOfEntry, timeOfEntry) ||
                other.timeOfEntry == timeOfEntry) &&
            (identical(other.amountInLocalCurrency, amountInLocalCurrency) ||
                other.amountInLocalCurrency == amountInLocalCurrency) &&
            (identical(other.qtyInOpun, qtyInOpun) ||
                other.qtyInOpun == qtyInOpun) &&
            (identical(other.qtyInOrderUnit, qtyInOrderUnit) ||
                other.qtyInOrderUnit == qtyInOrderUnit) &&
            (identical(other.localTime, localTime) ||
                other.localTime == localTime) &&
            (identical(other.localDate, localDate) ||
                other.localDate == localDate) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.storeRemarks, storeRemarks) ||
                other.storeRemarks == storeRemarks) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.aging, aging) || other.aging == aging) &&
            (identical(other.mdr, mdr) || other.mdr == mdr) &&
            (identical(other.scanningInvoiceStatus, scanningInvoiceStatus) ||
                other.scanningInvoiceStatus == scanningInvoiceStatus) &&
            (identical(other.scanningDate, scanningDate) ||
                other.scanningDate == scanningDate) &&
            (identical(other.vendor, vendor) || other.vendor == vendor) &&
            (identical(other.sourceVendorName, sourceVendorName) ||
                other.sourceVendorName == sourceVendorName) &&
            (identical(other.buyerName, buyerName) ||
                other.buyerName == buyerName) &&
            (identical(other.makerChecker, makerChecker) ||
                other.makerChecker == makerChecker));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        gateEntryNo,
        grnNo,
        poNumber,
        challanNo,
        matchedStatus,
        quantityDiff,
        vendorName,
        reconciledAt,
        srNo,
        remarks,
        duplicateReference,
        dublicate,
        referenceNo,
        reference,
        documentDate,
        quantity,
        material,
        materialDocument,
        postingDate,
        plant,
        materialDescription,
        movementType,
        movementTypeText,
        supplier,
        purchaseOrder,
        documentHeaderText,
        userName,
        entryDate,
        timeOfEntry,
        amountInLocalCurrency,
        qtyInOpun,
        qtyInOrderUnit,
        localTime,
        localDate,
        shift,
        storeRemarks,
        status,
        aging,
        mdr,
        scanningInvoiceStatus,
        scanningDate,
        vendor,
        sourceVendorName,
        buyerName,
        makerChecker
      ]);

  /// Create a copy of GrnReconReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GrnReconReportItemImplCopyWith<_$GrnReconReportItemImpl> get copyWith =>
      __$$GrnReconReportItemImplCopyWithImpl<_$GrnReconReportItemImpl>(
          this, _$identity);
}

abstract class _GrnReconReportItem implements GrnReconReportItem {
  const factory _GrnReconReportItem(
      {@JsonKey(name: 'gate_entry_no') final String? gateEntryNo,
      @JsonKey(name: 'grn_no') final String? grnNo,
      @JsonKey(name: 'po_number') final String? poNumber,
      @JsonKey(name: 'challan_no') final String? challanNo,
      @JsonKey(name: 'matched_status') final String? matchedStatus,
      @JsonKey(name: 'quantity_diff') final double? quantityDiff,
      @JsonKey(name: 'vendor_name') final String? vendorName,
      @JsonKey(name: 'reconciled_at') final String? reconciledAt,
      @JsonKey(name: 'sr_no') final String? srNo,
      @JsonKey(name: 'remarks') final String? remarks,
      @JsonKey(name: 'duplicate_reference') final String? duplicateReference,
      @JsonKey(name: 'dublicate') final String? dublicate,
      @JsonKey(name: 'reference_no') final String? referenceNo,
      @JsonKey(name: 'reference') final String? reference,
      @JsonKey(name: 'document_date') final String? documentDate,
      @JsonKey(name: 'quantity') final String? quantity,
      @JsonKey(name: 'material') final String? material,
      @JsonKey(name: 'material_document') final String? materialDocument,
      @JsonKey(name: 'posting_date') final String? postingDate,
      @JsonKey(name: 'plant') final String? plant,
      @JsonKey(name: 'material_description') final String? materialDescription,
      @JsonKey(name: 'movement_type') final String? movementType,
      @JsonKey(name: 'movement_type_text') final String? movementTypeText,
      @JsonKey(name: 'supplier') final String? supplier,
      @JsonKey(name: 'purchase_order') final String? purchaseOrder,
      @JsonKey(name: 'document_header_text') final String? documentHeaderText,
      @JsonKey(name: 'user_name') final String? userName,
      @JsonKey(name: 'entry_date') final String? entryDate,
      @JsonKey(name: 'time_of_entry') final String? timeOfEntry,
      @JsonKey(name: 'amount_in_local_currency')
      final String? amountInLocalCurrency,
      @JsonKey(name: 'qty_in_opun') final String? qtyInOpun,
      @JsonKey(name: 'qty_in_order_unit') final String? qtyInOrderUnit,
      @JsonKey(name: 'local_time') final String? localTime,
      @JsonKey(name: 'local_date') final String? localDate,
      @JsonKey(name: 'shift') final String? shift,
      @JsonKey(name: 'store_remarks') final String? storeRemarks,
      @JsonKey(name: 'status') final String? status,
      @JsonKey(name: 'aging') final String? aging,
      @JsonKey(name: 'mdr') final String? mdr,
      @JsonKey(name: 'scanning_invoice_status')
      final String? scanningInvoiceStatus,
      @JsonKey(name: 'scanning_date') final String? scanningDate,
      @JsonKey(name: 'vendor') final String? vendor,
      @JsonKey(name: 'source_vendor_name') final String? sourceVendorName,
      @JsonKey(name: 'buyer_name') final String? buyerName,
      @JsonKey(name: 'maker_checker')
      final String? makerChecker}) = _$GrnReconReportItemImpl;

  @override
  @JsonKey(name: 'gate_entry_no')
  String? get gateEntryNo;
  @override
  @JsonKey(name: 'grn_no')
  String? get grnNo;
  @override
  @JsonKey(name: 'po_number')
  String? get poNumber;
  @override
  @JsonKey(name: 'challan_no')
  String? get challanNo;
  @override
  @JsonKey(name: 'matched_status')
  String? get matchedStatus;
  @override
  @JsonKey(name: 'quantity_diff')
  double? get quantityDiff;
  @override
  @JsonKey(name: 'vendor_name')
  String? get vendorName;
  @override
  @JsonKey(name: 'reconciled_at')
  String? get reconciledAt;
  @override
  @JsonKey(name: 'sr_no')
  String? get srNo;
  @override
  @JsonKey(name: 'remarks')
  String? get remarks;
  @override
  @JsonKey(name: 'duplicate_reference')
  String? get duplicateReference;
  @override
  @JsonKey(name: 'dublicate')
  String? get dublicate;
  @override
  @JsonKey(name: 'reference_no')
  String? get referenceNo;
  @override
  @JsonKey(name: 'reference')
  String? get reference;
  @override
  @JsonKey(name: 'document_date')
  String? get documentDate;
  @override
  @JsonKey(name: 'quantity')
  String? get quantity;
  @override
  @JsonKey(name: 'material')
  String? get material;
  @override
  @JsonKey(name: 'material_document')
  String? get materialDocument;
  @override
  @JsonKey(name: 'posting_date')
  String? get postingDate;
  @override
  @JsonKey(name: 'plant')
  String? get plant;
  @override
  @JsonKey(name: 'material_description')
  String? get materialDescription;
  @override
  @JsonKey(name: 'movement_type')
  String? get movementType;
  @override
  @JsonKey(name: 'movement_type_text')
  String? get movementTypeText;
  @override
  @JsonKey(name: 'supplier')
  String? get supplier;
  @override
  @JsonKey(name: 'purchase_order')
  String? get purchaseOrder;
  @override
  @JsonKey(name: 'document_header_text')
  String? get documentHeaderText;
  @override
  @JsonKey(name: 'user_name')
  String? get userName;
  @override
  @JsonKey(name: 'entry_date')
  String? get entryDate;
  @override
  @JsonKey(name: 'time_of_entry')
  String? get timeOfEntry;
  @override
  @JsonKey(name: 'amount_in_local_currency')
  String? get amountInLocalCurrency;
  @override
  @JsonKey(name: 'qty_in_opun')
  String? get qtyInOpun;
  @override
  @JsonKey(name: 'qty_in_order_unit')
  String? get qtyInOrderUnit;
  @override
  @JsonKey(name: 'local_time')
  String? get localTime;
  @override
  @JsonKey(name: 'local_date')
  String? get localDate;
  @override
  @JsonKey(name: 'shift')
  String? get shift;
  @override
  @JsonKey(name: 'store_remarks')
  String? get storeRemarks;
  @override
  @JsonKey(name: 'status')
  String? get status;
  @override
  @JsonKey(name: 'aging')
  String? get aging;
  @override
  @JsonKey(name: 'mdr')
  String? get mdr;
  @override
  @JsonKey(name: 'scanning_invoice_status')
  String? get scanningInvoiceStatus;
  @override
  @JsonKey(name: 'scanning_date')
  String? get scanningDate;
  @override
  @JsonKey(name: 'vendor')
  String? get vendor;
  @override
  @JsonKey(name: 'source_vendor_name')
  String? get sourceVendorName;
  @override
  @JsonKey(name: 'buyer_name')
  String? get buyerName;
  @override
  @JsonKey(name: 'maker_checker')
  String? get makerChecker;

  /// Create a copy of GrnReconReportItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GrnReconReportItemImplCopyWith<_$GrnReconReportItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PendingGrnReportItem _$PendingGrnReportItemFromJson(Map<String, dynamic> json) {
  return _PendingGrnReportItem.fromJson(json);
}

/// @nodoc
mixin _$PendingGrnReportItem {
  String get gateEntryNo => throw _privateConstructorUsedError;
  String get poNumber => throw _privateConstructorUsedError;
  String get vendor => throw _privateConstructorUsedError;
  String get material => throw _privateConstructorUsedError;
  int get daysPending => throw _privateConstructorUsedError;

  /// Serializes this PendingGrnReportItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PendingGrnReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PendingGrnReportItemCopyWith<PendingGrnReportItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PendingGrnReportItemCopyWith<$Res> {
  factory $PendingGrnReportItemCopyWith(PendingGrnReportItem value,
          $Res Function(PendingGrnReportItem) then) =
      _$PendingGrnReportItemCopyWithImpl<$Res, PendingGrnReportItem>;
  @useResult
  $Res call(
      {String gateEntryNo,
      String poNumber,
      String vendor,
      String material,
      int daysPending});
}

/// @nodoc
class _$PendingGrnReportItemCopyWithImpl<$Res,
        $Val extends PendingGrnReportItem>
    implements $PendingGrnReportItemCopyWith<$Res> {
  _$PendingGrnReportItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PendingGrnReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = null,
    Object? poNumber = null,
    Object? vendor = null,
    Object? material = null,
    Object? daysPending = null,
  }) {
    return _then(_value.copyWith(
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      poNumber: null == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String,
      vendor: null == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String,
      material: null == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String,
      daysPending: null == daysPending
          ? _value.daysPending
          : daysPending // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PendingGrnReportItemImplCopyWith<$Res>
    implements $PendingGrnReportItemCopyWith<$Res> {
  factory _$$PendingGrnReportItemImplCopyWith(_$PendingGrnReportItemImpl value,
          $Res Function(_$PendingGrnReportItemImpl) then) =
      __$$PendingGrnReportItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String gateEntryNo,
      String poNumber,
      String vendor,
      String material,
      int daysPending});
}

/// @nodoc
class __$$PendingGrnReportItemImplCopyWithImpl<$Res>
    extends _$PendingGrnReportItemCopyWithImpl<$Res, _$PendingGrnReportItemImpl>
    implements _$$PendingGrnReportItemImplCopyWith<$Res> {
  __$$PendingGrnReportItemImplCopyWithImpl(_$PendingGrnReportItemImpl _value,
      $Res Function(_$PendingGrnReportItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of PendingGrnReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gateEntryNo = null,
    Object? poNumber = null,
    Object? vendor = null,
    Object? material = null,
    Object? daysPending = null,
  }) {
    return _then(_$PendingGrnReportItemImpl(
      gateEntryNo: null == gateEntryNo
          ? _value.gateEntryNo
          : gateEntryNo // ignore: cast_nullable_to_non_nullable
              as String,
      poNumber: null == poNumber
          ? _value.poNumber
          : poNumber // ignore: cast_nullable_to_non_nullable
              as String,
      vendor: null == vendor
          ? _value.vendor
          : vendor // ignore: cast_nullable_to_non_nullable
              as String,
      material: null == material
          ? _value.material
          : material // ignore: cast_nullable_to_non_nullable
              as String,
      daysPending: null == daysPending
          ? _value.daysPending
          : daysPending // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PendingGrnReportItemImpl implements _PendingGrnReportItem {
  const _$PendingGrnReportItemImpl(
      {required this.gateEntryNo,
      required this.poNumber,
      required this.vendor,
      required this.material,
      required this.daysPending});

  factory _$PendingGrnReportItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$PendingGrnReportItemImplFromJson(json);

  @override
  final String gateEntryNo;
  @override
  final String poNumber;
  @override
  final String vendor;
  @override
  final String material;
  @override
  final int daysPending;

  @override
  String toString() {
    return 'PendingGrnReportItem(gateEntryNo: $gateEntryNo, poNumber: $poNumber, vendor: $vendor, material: $material, daysPending: $daysPending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PendingGrnReportItemImpl &&
            (identical(other.gateEntryNo, gateEntryNo) ||
                other.gateEntryNo == gateEntryNo) &&
            (identical(other.poNumber, poNumber) ||
                other.poNumber == poNumber) &&
            (identical(other.vendor, vendor) || other.vendor == vendor) &&
            (identical(other.material, material) ||
                other.material == material) &&
            (identical(other.daysPending, daysPending) ||
                other.daysPending == daysPending));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, gateEntryNo, poNumber, vendor, material, daysPending);

  /// Create a copy of PendingGrnReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PendingGrnReportItemImplCopyWith<_$PendingGrnReportItemImpl>
      get copyWith =>
          __$$PendingGrnReportItemImplCopyWithImpl<_$PendingGrnReportItemImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PendingGrnReportItemImplToJson(
      this,
    );
  }
}

abstract class _PendingGrnReportItem implements PendingGrnReportItem {
  const factory _PendingGrnReportItem(
      {required final String gateEntryNo,
      required final String poNumber,
      required final String vendor,
      required final String material,
      required final int daysPending}) = _$PendingGrnReportItemImpl;

  factory _PendingGrnReportItem.fromJson(Map<String, dynamic> json) =
      _$PendingGrnReportItemImpl.fromJson;

  @override
  String get gateEntryNo;
  @override
  String get poNumber;
  @override
  String get vendor;
  @override
  String get material;
  @override
  int get daysPending;

  /// Create a copy of PendingGrnReportItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PendingGrnReportItemImplCopyWith<_$PendingGrnReportItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}

AuditTrailReportItem _$AuditTrailReportItemFromJson(Map<String, dynamic> json) {
  return _AuditTrailReportItem.fromJson(json);
}

/// @nodoc
mixin _$AuditTrailReportItem {
  DateTime get date => throw _privateConstructorUsedError;
  String get user => throw _privateConstructorUsedError;
  String get action => throw _privateConstructorUsedError;
  String get entity => throw _privateConstructorUsedError;
  String get changes => throw _privateConstructorUsedError;

  /// Serializes this AuditTrailReportItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AuditTrailReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuditTrailReportItemCopyWith<AuditTrailReportItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuditTrailReportItemCopyWith<$Res> {
  factory $AuditTrailReportItemCopyWith(AuditTrailReportItem value,
          $Res Function(AuditTrailReportItem) then) =
      _$AuditTrailReportItemCopyWithImpl<$Res, AuditTrailReportItem>;
  @useResult
  $Res call(
      {DateTime date,
      String user,
      String action,
      String entity,
      String changes});
}

/// @nodoc
class _$AuditTrailReportItemCopyWithImpl<$Res,
        $Val extends AuditTrailReportItem>
    implements $AuditTrailReportItemCopyWith<$Res> {
  _$AuditTrailReportItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuditTrailReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? user = null,
    Object? action = null,
    Object? entity = null,
    Object? changes = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      entity: null == entity
          ? _value.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as String,
      changes: null == changes
          ? _value.changes
          : changes // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AuditTrailReportItemImplCopyWith<$Res>
    implements $AuditTrailReportItemCopyWith<$Res> {
  factory _$$AuditTrailReportItemImplCopyWith(_$AuditTrailReportItemImpl value,
          $Res Function(_$AuditTrailReportItemImpl) then) =
      __$$AuditTrailReportItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime date,
      String user,
      String action,
      String entity,
      String changes});
}

/// @nodoc
class __$$AuditTrailReportItemImplCopyWithImpl<$Res>
    extends _$AuditTrailReportItemCopyWithImpl<$Res, _$AuditTrailReportItemImpl>
    implements _$$AuditTrailReportItemImplCopyWith<$Res> {
  __$$AuditTrailReportItemImplCopyWithImpl(_$AuditTrailReportItemImpl _value,
      $Res Function(_$AuditTrailReportItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of AuditTrailReportItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? user = null,
    Object? action = null,
    Object? entity = null,
    Object? changes = null,
  }) {
    return _then(_$AuditTrailReportItemImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      entity: null == entity
          ? _value.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as String,
      changes: null == changes
          ? _value.changes
          : changes // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AuditTrailReportItemImpl implements _AuditTrailReportItem {
  const _$AuditTrailReportItemImpl(
      {required this.date,
      required this.user,
      required this.action,
      required this.entity,
      required this.changes});

  factory _$AuditTrailReportItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$AuditTrailReportItemImplFromJson(json);

  @override
  final DateTime date;
  @override
  final String user;
  @override
  final String action;
  @override
  final String entity;
  @override
  final String changes;

  @override
  String toString() {
    return 'AuditTrailReportItem(date: $date, user: $user, action: $action, entity: $entity, changes: $changes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuditTrailReportItemImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.changes, changes) || other.changes == changes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, date, user, action, entity, changes);

  /// Create a copy of AuditTrailReportItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuditTrailReportItemImplCopyWith<_$AuditTrailReportItemImpl>
      get copyWith =>
          __$$AuditTrailReportItemImplCopyWithImpl<_$AuditTrailReportItemImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AuditTrailReportItemImplToJson(
      this,
    );
  }
}

abstract class _AuditTrailReportItem implements AuditTrailReportItem {
  const factory _AuditTrailReportItem(
      {required final DateTime date,
      required final String user,
      required final String action,
      required final String entity,
      required final String changes}) = _$AuditTrailReportItemImpl;

  factory _AuditTrailReportItem.fromJson(Map<String, dynamic> json) =
      _$AuditTrailReportItemImpl.fromJson;

  @override
  DateTime get date;
  @override
  String get user;
  @override
  String get action;
  @override
  String get entity;
  @override
  String get changes;

  /// Create a copy of AuditTrailReportItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuditTrailReportItemImplCopyWith<_$AuditTrailReportItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}
