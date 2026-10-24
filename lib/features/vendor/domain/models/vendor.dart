enum VendorType {
  purchase('purchase', 'Purchase'),
  soldTo('sold_to', 'Sold To');

  final String apiValue;
  final String label;
  const VendorType(this.apiValue, this.label);

  static VendorType? fromApi(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    for (final t in VendorType.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}

class Vendor {
  final String id;
  final String vendorCode;
  final String vendorName;
  final VendorType vendorType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// How many purchase orders / materials the vendor master holds for this
  /// vendor (filled by the list endpoint; 0 elsewhere).
  final int purchaseOrderCount;
  final int materialCount;

  const Vendor({
    required this.id,
    required this.vendorCode,
    required this.vendorName,
    required this.vendorType,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.purchaseOrderCount = 0,
    this.materialCount = 0,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: (json['id'] ?? '').toString(),
      vendorCode: (json['vendorCode'] ?? json['vendor_code'] ?? '').toString(),
      vendorName: (json['vendorName'] ?? json['vendor_name'] ?? '').toString(),
      vendorType: VendorType.fromApi(
            (json['vendorType'] ?? json['vendor_type'])?.toString(),
          ) ??
          VendorType.purchase,
      isActive: _toBool(json['isActive'] ?? json['is_active']) ?? true,
      createdAt: _toDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _toDate(json['updatedAt'] ?? json['updated_at']),
      purchaseOrderCount: (json['purchaseOrderCount'] as num?)?.toInt() ?? 0,
      materialCount: (json['materialCount'] as num?)?.toInt() ?? 0,
    );
  }

  Vendor copyWith({
    String? id,
    String? vendorCode,
    String? vendorName,
    VendorType? vendorType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      vendorCode: vendorCode ?? this.vendorCode,
      vendorName: vendorName ?? this.vendorName,
      vendorType: vendorType ?? this.vendorType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return null;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

class VendorListResult {
  final List<Vendor> vendors;
  final int limit;
  final int offset;
  final int count;

  const VendorListResult({
    required this.vendors,
    required this.limit,
    required this.offset,
    required this.count,
  });
}

class VendorListQuery {
  final String? query;
  final VendorType? vendorType;
  final bool? isActive;
  final int limit;
  final int offset;

  const VendorListQuery({
    this.query,
    this.vendorType,
    this.isActive,
    this.limit = 50,
    this.offset = 0,
  });

  VendorListQuery copyWith({
    Object? query = _sentinel,
    Object? vendorType = _sentinel,
    Object? isActive = _sentinel,
    int? limit,
    int? offset,
  }) {
    return VendorListQuery(
      query: identical(query, _sentinel) ? this.query : query as String?,
      vendorType: identical(vendorType, _sentinel)
          ? this.vendorType
          : vendorType as VendorType?,
      isActive:
          identical(isActive, _sentinel) ? this.isActive : isActive as bool?,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  static const Object _sentinel = Object();
}

class VendorWriteRequest {
  final String? vendorCode;
  final String? vendorName;
  final VendorType? vendorType;
  final bool? isActive;

  const VendorWriteRequest({
    this.vendorCode,
    this.vendorName,
    this.vendorType,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      if (vendorCode != null) 'vendorCode': vendorCode,
      if (vendorName != null) 'vendorName': vendorName,
      if (vendorType != null) 'vendorType': vendorType!.apiValue,
      if (isActive != null) 'isActive': isActive,
    };
  }
}
