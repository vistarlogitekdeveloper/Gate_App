import 'models/vendor.dart';
import 'models/vendor_po_material.dart';

abstract class VendorRepository {
  Future<VendorListResult> listVendors(VendorListQuery query);
  Future<Vendor> getVendor(String id);
  Future<Vendor> createVendor(VendorWriteRequest request);
  Future<Vendor> updateVendor(String id, VendorWriteRequest request);
  Future<void> deleteVendor(String id, {bool hard = false});

  /// The purchase orders and materials the vendor master holds for a vendor.
  Future<List<VendorPoMaterial>> getVendorPurchaseOrders(String id);

  /// Replace the purchase vendors and their PO / material list from the
  /// client's SAP export (admin only). [dryRun] previews without writing.
  /// Pass [filePath] (mobile) or [bytes] (web).
  Future<VendorImportSummary> importVendorMaster({
    required String fileName,
    String? filePath,
    List<int>? bytes,
    required bool dryRun,
  });
}
