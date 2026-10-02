import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/pagination_model.dart';
import '../domain/gate_entry_repository.dart';
import '../domain/models/attachment.dart';
import '../domain/models/gate_entry.dart';
import '../domain/models/gate_entry_item.dart';
import '../domain/models/gate_entry_list_response.dart';
import '../domain/models/gate_entry_query.dart';
import '../domain/models/gate_entry_summary.dart';
import '../domain/models/scanned_document.dart';
import '../domain/models/vendor.dart';
import 'dto/create_gate_entry_request.dart';
import 'dto/gate_entry_response.dart';
import 'dto/check_challan_uniqueness_response.dart';

final gateEntryRepositoryProvider = Provider<GateEntryRepository>((ref) {
  return GateEntryRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class GateEntryRepositoryImpl implements GateEntryRepository {
  final ApiClient _apiClient;

  GateEntryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  GateEntry _mapDtoToDomain(GateEntryResponse dto) {
    return GateEntry(
      id: dto.id,
      gateEntryNo: dto.gateEntryNo,
      gateTimestamp: dto.gateTimestamp != null
          ? DateTime.tryParse(dto.gateTimestamp!)
          : null,
      gateMovement: dto.gateMovement.toLowerCase().contains('in')
          ? GateMovement.inMovement
          : GateMovement.outMovement,
      challanNo: dto.challanNo,
      lrNumber: dto.lrNumber,
      transporterName: dto.transporterName,
      vehicleNo: dto.vehicleNo,
      driverContactNo: dto.driverContactNo,
      vendorCode: dto.vendorCode,
      vendorName: dto.vendorName,
      status: dto.status ?? 'unknown',
      items: dto.items
          .map((item) => GateEntryItem(
                id: item.id,
                poNumber: item.poNumber,
                materialCode: item.materialCode,
                challanQty: item.challanQty,
                uom: item.uom,
                challanNo: item.challanNo,
              ))
          .toList(),
      gateOutTimestamp: dto.gateOutTimestamp != null
          ? DateTime.tryParse(dto.gateOutTimestamp!)
          : null,
      gateOutBy: dto.gateOutBy,
      noOfLineItems: dto.noOfLineItems,
      remark: dto.remark,
    );
  }

  @override
  Future<ApiResponse<GateEntryListResponse>> getGateEntries({
    GateEntryQuery? query,
  }) async {
    try {
      // Apply a safe default limit when no query is provided. Without it the
      // server returns its full default page and large sites stalled the UI
      // for seconds parsing the response on the main isolate.
      final params = query?.toQueryParameters() ?? const {'limit': 100};
      final response = await _apiClient.getRaw(
        '/gate-entries',
        queryParameters: params,
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';

      if (success) {
        final List<dynamic> rawItems =
            (response['data'] as List<dynamic>? ?? []);
        final items = rawItems
            .map((json) => _mapDtoToDomain(GateEntryResponse.fromJson(json)))
            .toList();

        final paginationJson = response['pagination'] as Map<String, dynamic>?;
        final pagination = paginationJson == null
            ? null
            : PaginationModel.fromJson(paginationJson);
        final summaryJson = response['summary'] as Map<String, dynamic>?;
        final summary = summaryJson == null
            ? const GateEntrySummary()
            : GateEntrySummary.fromJson(summaryJson);

        return ApiResponse<GateEntryListResponse>(
          success: true,
          message: message,
          data: GateEntryListResponse(
            items: items,
            summary: summary,
            pagination: pagination,
          ),
        );
      }

      final error = response['error'] is Map<String, dynamic>
          ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
          : null;
      return ApiResponse<GateEntryListResponse>(
        success: false,
        message: message,
        error: error,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to fetch gate entries',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<GateEntry>> getGateEntry(String id) async {
    final response = await _apiClient.get<GateEntryResponse>(
      '/gate-entries/$id',
      fromJsonT: (json) => GateEntryResponse.fromJson(json),
    );

    if (response.success && response.data != null) {
      return ApiResponse<GateEntry>(
        success: true,
        message: response.message,
        data: _mapDtoToDomain(response.data!),
      );
    }

    return ApiResponse<GateEntry>(
      success: false,
      message: response.message,
      error: response.error,
    );
  }

  @override
  Future<ApiResponse<GateEntry>> createGateEntry(
      CreateGateEntryRequest request) async {
    try {
      final response = await _apiClient.postRaw(
        '/gate-entries',
        data: request.toJson(),
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<GateEntry>(
          success: false,
          message: message,
          error: error,
        );
      }

      final data = response['data'];
      GateEntry? parsed;

      if (data is Map<String, dynamic>) {
        try {
          parsed = _mapDtoToDomain(GateEntryResponse.fromJson(data));
        } catch (_) {}
      } else if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        try {
          parsed = _mapDtoToDomain(
            GateEntryResponse.fromJson(data.first as Map<String, dynamic>),
          );
        } catch (_) {}
      }

      parsed ??= GateEntry(
        id: '',
        gateEntryNo: null,
        gateMovement: request.gateMovement.toLowerCase().contains('in')
            ? GateMovement.inMovement
            : GateMovement.outMovement,
        challanNo: request.invoiceEntries.isNotEmpty
            ? request.invoiceEntries.first.challanNo
            : ((request.challanNos != null && request.challanNos!.isNotEmpty)
                ? request.challanNos!.first
                : request.challanNo),
        lrNumber: request.lrNumber,
        transporterName: request.transporterName,
        vehicleNo: request.vehicleNo,
        driverContactNo: request.driverContactNo,
        vendorCode: request.vendorCode,
        vendorName: request.vendorName,
        items: request.invoiceEntries.isNotEmpty
            ? request.invoiceEntries
                .map(
                  (entry) => GateEntryItem(
                    id: null,
                    poNumber: entry.poNumber,
                    materialCode: entry.partNumber,
                    challanQty: entry.quantity,
                    uom: entry.uom,
                    challanNo: entry.challanNo,
                  ),
                )
                .toList()
            : request.items
                .map(
                  (item) => GateEntryItem(
                    id: item.id,
                    poNumber: item.poNumber,
                    materialCode: item.materialCode,
                    challanQty: item.challanQty,
                    uom: item.uom,
                    challanNo: item.challanNo,
                  ),
                )
                .toList(),
        status: 'Pending',
        gateTimestamp: DateTime.now(),
        noOfLineItems: request.noOfLineItems,
        remark: request.remark,
      );

      return ApiResponse<GateEntry>(
        success: true,
        message: message,
        data: parsed,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to create gate entry',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<GateEntry>> updateGateEntry(
      String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch<GateEntryResponse>(
      '/gate-entries/$id',
      data: data,
      fromJsonT: (json) => GateEntryResponse.fromJson(json),
    );

    if (response.success && response.data != null) {
      return ApiResponse<GateEntry>(
        success: true,
        message: response.message,
        data: _mapDtoToDomain(response.data!),
      );
    }

    return ApiResponse<GateEntry>(
      success: false,
      message: response.message,
      error: response.error,
    );
  }

  @override
  Future<ApiResponse<void>> verifyGateEntry(String id) async {
    return _apiClient.post<void>('/gate-entries/$id/verify');
  }

  @override
  Future<({bool exempt, String? reason})> getGrnExemptState(String id) async {
    try {
      final response = await _apiClient.getRaw('/gate-entries/$id');
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final reason = data['grnExemptReason'];
        return (
          exempt: data['grnExempt'] == true,
          reason: reason is String && reason.trim().isNotEmpty
              ? reason.trim()
              : null,
        );
      }
    } catch (_) {
      // Non-fatal — the screen falls back to showing the un-marked state
      // rather than failing to render the gate entry.
    }
    return (exempt: false, reason: null);
  }

  @override
  Future<ApiResponse<void>> setGrnExempt(
    String id, {
    required bool exempt,
    String? reason,
  }) async {
    return _apiClient.post<void>(
      '/gate-entries/$id/grn-exempt',
      data: {
        'exempt': exempt,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  @override
  Future<ApiResponse<void>> approveGateEntry(String id) async {
    return _apiClient.post<void>('/gate-entries/$id/approve');
  }

  @override
  Future<ApiResponse<void>> closeGateEntry(String id) async {
    return _apiClient.post<void>('/gate-entries/$id/close');
  }

  @override
  Future<ApiResponse<List<AttachmentInfo>>> getAttachments(String id) async {
    try {
      final response = await _apiClient.getRaw('/gate-entries/$id');

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<List<AttachmentInfo>>(
          success: false,
          message: message,
          error: error,
        );
      }

      final data = response['data'];
      final detail =
          data is Map<String, dynamic> ? data : const <String, dynamic>{};
      final list = detail['attachments'] as List? ?? const [];
      final attachments = list
          .map((e) {
            final map = e as Map<String, dynamic>;
            final idValue = (map['id'] ??
                    map['attachmentId'] ??
                    map['attachment_id'] ??
                    '')
                .toString();
            if (idValue.isEmpty) return null;
            final nameValue = (map['fileName'] ??
                    map['filename'] ??
                    map['name'] ??
                    idValue)
                .toString();
            return AttachmentInfo(id: idValue, fileName: nameValue);
          })
          .whereType<AttachmentInfo>()
          .toList();

      return ApiResponse<List<AttachmentInfo>>(
        success: true,
        message: message,
        data: attachments,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load attachments',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<ScannedDocument>> scanDocument({
    required String fileName,
    String? filePath,
    List<int>? bytes,
    String? recognized,
    String profile = 'gate-challan',
  }) async {
    try {
      // Same two-way split as uploadAttachment: mobile hands us a path, web
      // hands us bytes.
      MultipartFile filePart;
      if (filePath != null && filePath.isNotEmpty) {
        filePart = await MultipartFile.fromFile(filePath, filename: fileName);
      } else if (bytes != null && bytes.isNotEmpty) {
        filePart = MultipartFile.fromBytes(bytes, filename: fileName);
      } else {
        return ApiResponse(
          success: false,
          message: 'No photo to scan',
          error: ApiError(message: 'Missing file data'),
        );
      }

      final formData = FormData.fromMap({
        'file': filePart,
        'gateMovement': 'in',
        'profile': profile,
        // On-device recognition, when the phone managed it. A server that does
        // not yet understand this field simply ignores it and reads the photo
        // as before, so this build is safe to ship ahead of the backend.
        if (recognized != null && recognized.isNotEmpty) 'recognized': recognized,
      });

      final response = await _apiClient.postRaw(
        ApiEndpoints.gateEntryScan,
        data: formData,
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<ScannedDocument>(
          success: false,
          message: message,
          error: error ?? ApiError(message: message),
        );
      }

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        return ApiResponse<ScannedDocument>(
          success: false,
          message: 'Unexpected scan response',
          error: ApiError(message: 'Unexpected scan response'),
        );
      }

      // A document that could not be read is still a SUCCESSFUL call — the
      // scan ran, the paper was illegible, and the warnings say why. Passing
      // it through as success lets the UI show "the photo is out of focus,
      // retake it" instead of a generic failure.
      return ApiResponse<ScannedDocument>(
        success: true,
        message: message,
        data: ScannedDocument.fromJson(data),
      );
    } catch (e) {
      return ApiResponse<ScannedDocument>(
        success: false,
        message: 'Could not scan the document',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<AttachmentInfo>> uploadAttachment(
    String id, {
    required String fileName,
    String? filePath,
    List<int>? bytes,
  }) async {
    try {
      MultipartFile filePart;
      if (filePath != null && filePath.isNotEmpty) {
        filePart = await MultipartFile.fromFile(filePath, filename: fileName);
      } else if (bytes != null) {
        filePart = MultipartFile.fromBytes(bytes, filename: fileName);
      } else {
        return ApiResponse(
          success: false,
          message: 'No attachment data provided',
          error: ApiError(message: 'Missing file data'),
        );
      }

      final formData = FormData.fromMap({'file': filePart});
      final response = await _apiClient.postRaw(
        '/gate-entries/$id/attachments',
        data: formData,
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<AttachmentInfo>(
          success: false,
          message: message,
          error: error,
        );
      }

      final data = response['data'];
      String idValue = '';
      String nameValue = fileName;
      if (data is Map<String, dynamic>) {
        idValue = (data['id'] ??
                data['attachmentId'] ??
                data['attachment_id'] ??
                '')
            .toString();
        nameValue = (data['fileName'] ??
                data['filename'] ??
                data['name'] ??
                fileName)
            .toString();
      }

      if (idValue.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'Attachment upload failed',
          error: ApiError(message: 'Missing attachment id in response'),
        );
      }

      return ApiResponse<AttachmentInfo>(
        success: true,
        message: message,
        data: AttachmentInfo(id: idValue, fileName: nameValue),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to upload attachment',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<String>> getAttachmentUrl(
      String id, String attachmentId) async {
    try {
      final response = await _apiClient.getRaw(
        '/gate-entries/$id/attachments/$attachmentId/url',
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<String>(
          success: false,
          message: message,
          error: error,
        );
      }

      String url = '';
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        url = (data['url'] ?? data['signedUrl'] ?? '').toString();
      } else if (data is String) {
        url = data;
      } else if (response['url'] != null) {
        url = response['url'].toString();
      }

      if (url.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'Attachment URL not found',
          error: ApiError(message: 'Missing attachment URL in response'),
        );
      }

      return ApiResponse<String>(success: true, message: message, data: url);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to fetch attachment URL',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<List<Vendor>>> searchVendors(String query) async {
    try {
      final response = await _apiClient.getRaw(
        '/gate-entries/vendors',
        queryParameters: {'q': query},
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';
      if (!success) {
        final error = response['error'] is Map<String, dynamic>
            ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
            : null;
        return ApiResponse<List<Vendor>>(
          success: false,
          message: message,
          error: error,
        );
      }

      final List<dynamic> rawData = response['data'] as List<dynamic>? ?? [];
      final vendors = rawData
          .map((json) => Vendor.fromJson(json as Map<String, dynamic>))
          .toList();

      return ApiResponse<List<Vendor>>(
        success: true,
        message: message,
        data: vendors,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Vendor search failed',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<CheckChallanUniquenessResponse>> checkChallanUniqueness(
    String challanNo, {
    String? vendorCode,
    String? financialYear,
  }) async {
    try {
      final queryParams = {'challanNo': challanNo};
      if (vendorCode != null && vendorCode.isNotEmpty) {
        queryParams['vendorCode'] = vendorCode;
      }
      // Ask the backend to scope the uniqueness check to the given FY.
      // Older servers that don't recognise this param will ignore it and
      // fall back to their default (all-time) check, which is still
      // strictly at-least-as-strict as FY.
      if (financialYear != null && financialYear.isNotEmpty) {
        queryParams['financialYear'] = financialYear;
        queryParams['fy'] = financialYear;
      }

      final response = await _apiClient.getRaw(
        '/gate-entries/challan-unique',
        queryParameters: queryParams,
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';

      if (!success) {
        return ApiResponse<CheckChallanUniquenessResponse>(
          success: false,
          message: message,
          error: response['error'] is Map<String, dynamic>
              ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
              : ApiError(message: message),
          data: CheckChallanUniquenessResponse.fromJson(response), 
        );
      }

      return ApiResponse<CheckChallanUniquenessResponse>(
        success: true,
        message: message,
        data: CheckChallanUniquenessResponse.fromJson(response),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Challan uniqueness check failed',
        error: ApiError(message: e.toString()),
      );
    }
  }

  @override
  Future<ApiResponse<GateEntry>> gateOut(String id, {String? remarks}) async {
    try {
      final response = await _apiClient.postRaw(
        '/gate-entries/$id/gate-out',
        data: remarks != null ? {'remarks': remarks} : null,
      );

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';

      if (success) {
        final data = response['data'] as Map<String, dynamic>;
        return ApiResponse<GateEntry>(
          success: true,
          message: message,
          data: _mapDtoToDomain(GateEntryResponse.fromJson(data)),
        );
      }

      final error = response['error'] is Map<String, dynamic>
          ? ApiError.fromJson(response['error'] as Map<String, dynamic>)
          : null;
      return ApiResponse<GateEntry>(
        success: false,
        message: message,
        error: error,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to record gate out',
        error: ApiError(message: e.toString()),
      );
    }
  }
}
