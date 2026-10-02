import '../../../core/network/api_response.dart';
import '../data/dto/create_gate_entry_request.dart';
import '../data/dto/check_challan_uniqueness_response.dart';
import 'models/attachment.dart';
import 'models/gate_entry.dart';
import 'models/gate_entry_list_response.dart';
import 'models/gate_entry_query.dart';
import 'models/scanned_document.dart';
import 'models/vendor.dart';

abstract class GateEntryRepository {
  Future<ApiResponse<GateEntryListResponse>> getGateEntries({
    GateEntryQuery? query,
  });
  Future<ApiResponse<GateEntry>> getGateEntry(String id);
  Future<ApiResponse<GateEntry>> createGateEntry(
      CreateGateEntryRequest request);
  Future<ApiResponse<GateEntry>> updateGateEntry(
      String id, Map<String, dynamic> data);
  Future<ApiResponse<void>> verifyGateEntry(String id);

  /// Current GRN-exemption state for one entry.
  ///
  /// Read straight from the API rather than carried on [GateEntry]: adding a
  /// field to that model means regenerating freezed, and these two values are
  /// only needed on the detail screen.
  Future<({bool exempt, String? reason})> getGrnExemptState(String id);

  /// Flags a gate entry as one that will never receive a SAP GRN
  /// ("Not for Cytiva"), or clears that flag when [exempt] is false.
  /// Manager/admin only — enforced server-side.
  Future<ApiResponse<void>> setGrnExempt(
    String id, {
    required bool exempt,
    String? reason,
  });
  Future<ApiResponse<void>> approveGateEntry(String id);
  Future<ApiResponse<void>> closeGateEntry(String id);
  Future<ApiResponse<List<AttachmentInfo>>> getAttachments(String id);
  /// Read a photographed challan / invoice into a draft gate entry.
  ///
  /// Pass either [filePath] (mobile) or [bytes] (web) — the same split the
  /// attachment upload uses. Nothing is created: the result is a draft for
  /// the guard to confirm, which is why this is safe to call as often as the
  /// photo is retaken.
  /// [recognized] is the result of reading the page ON THE PHONE (ML Kit),
  /// JSON-encoded. When supplied the server uses it instead of running its own
  /// OCR — the phone is far better at a handheld photo than server-side
  /// Tesseract is. The photo is sent regardless: the server needs it to fall
  /// back, and sending both lets the two engines be compared on identical
  /// input while we decide.
  Future<ApiResponse<ScannedDocument>> scanDocument({
    required String fileName,
    String? filePath,
    List<int>? bytes,
    String? recognized,
    String profile,
  });

  Future<ApiResponse<AttachmentInfo>> uploadAttachment(
    String id, {
    required String fileName,
    String? filePath,
    List<int>? bytes,
  });
  Future<ApiResponse<String>> getAttachmentUrl(String id, String attachmentId);
  Future<ApiResponse<List<Vendor>>> searchVendors(String query);
  Future<ApiResponse<CheckChallanUniquenessResponse>> checkChallanUniqueness(
    String challanNo, {
    String? vendorCode,
    String? financialYear,
  });
  Future<ApiResponse<GateEntry>> gateOut(String id, {String? remarks});
}
