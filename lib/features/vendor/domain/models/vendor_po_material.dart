/// One purchase order of a vendor and the material on it, from the vendor
/// master (GET /gate-entries/purchase-orders,
/// GET /vendor-master/:id/purchase-orders).
///
/// [vendorName] is only filled when a PO was searched for before the vendor
/// was chosen — the gate entry form then fills the vendor in from it.
class VendorPoMaterial {
  final String poNumber;
  final String? materialCode;
  final String vendorCode;
  final String? vendorName;

  const VendorPoMaterial({
    required this.poNumber,
    required this.materialCode,
    required this.vendorCode,
    this.vendorName,
  });

  factory VendorPoMaterial.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return VendorPoMaterial(
      poNumber: text(json['poNumber']) ?? '',
      materialCode: text(json['materialCode']),
      vendorCode: text(json['vendorCode']) ?? '',
      vendorName: text(json['vendorName']),
    );
  }

  static List<VendorPoMaterial> listFrom(dynamic data) => data is List
      ? data
          .whereType<Map<String, dynamic>>()
          .map(VendorPoMaterial.fromJson)
          .where((r) => r.poNumber.isNotEmpty)
          .toList()
      : const [];
}

/// What a vendor master import did, or would do (dry run).
class VendorImportSummary {
  final bool dryRun;
  final int rows;
  final int vendors;
  final int purchaseOrders;
  final int materials;
  final int added;
  final int renamed;
  final int reactivated;
  final int unchanged;
  final int deleted;
  final List<({String vendorCode, String vendorName})> deletedVendors;
  final int errorCount;
  final List<({int row, String message})> errors;
  final List<String> warnings;

  const VendorImportSummary({
    required this.dryRun,
    required this.rows,
    required this.vendors,
    required this.purchaseOrders,
    required this.materials,
    required this.added,
    required this.renamed,
    required this.reactivated,
    required this.unchanged,
    required this.deleted,
    required this.deletedVendors,
    required this.errorCount,
    required this.errors,
    required this.warnings,
  });

  factory VendorImportSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    List<Map<String, dynamic>> maps(String key) => json[key] is List
        ? (json[key] as List).whereType<Map<String, dynamic>>().toList()
        : const [];
    return VendorImportSummary(
      dryRun: json['dryRun'] == true,
      rows: n('rows'),
      vendors: n('vendors'),
      purchaseOrders: n('purchaseOrders'),
      materials: n('materials'),
      added: n('added'),
      renamed: n('renamed'),
      reactivated: n('reactivated'),
      unchanged: n('unchanged'),
      deleted: n('deleted'),
      deletedVendors: maps('deletedVendors')
          .map((m) => (
                vendorCode: (m['vendorCode'] ?? '').toString(),
                vendorName: (m['vendorName'] ?? '').toString(),
              ))
          .toList(),
      errorCount: n('errorCount'),
      errors: maps('errors')
          .map((m) => (
                row: (m['row'] as num?)?.toInt() ?? 0,
                message: (m['message'] ?? '').toString(),
              ))
          .toList(),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).map((w) => w.toString()).toList()
          : const [],
    );
  }
}
