import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/vehicle_report.dart';

final vehicleReportRepositoryProvider = Provider<VehicleReportRepository>(
  (ref) => VehicleReportRepository(ref.read(apiClientProvider)),
);

/// Vehicles reported outside the gate (QR code form) and the At Gate list.
class VehicleReportRepository {
  VehicleReportRepository(this._api);

  final ApiClient _api;

  static String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  /// waiting (all, oldest first) or history (newest first, paged).
  Future<VehicleReportPage> list({
    bool history = false,
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final res = await _api.getRaw('/vehicle-reports', queryParameters: {
        if (history) 'view': 'history',
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        if (history) 'page': '$page',
        if (history) 'limit': '$limit',
      });
      final data = res['data'];
      final reports = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(VehicleReport.fromJson)
              .where((r) => r.id.isNotEmpty)
              .toList()
          : <VehicleReport>[];
      final p = res['pagination'];
      int intOf(String key, int fallback) =>
          p is Map && p[key] is num ? (p[key] as num).toInt() : fallback;
      return VehicleReportPage(
        reports: reports,
        page: intOf('page', page),
        totalPages: intOf('totalPages', reports.isEmpty ? 0 : 1),
        total: intOf('total', reports.length),
      );
    } catch (e) {
      throw Exception(_clean(e));
    }
  }

  /// The waiting report of this vehicle number, or null (also on any error:
  /// it is only a hint on the gate entry form).
  Future<VehicleReport?> match(String vehicleNo) async {
    try {
      final res = await _api.getRaw('/vehicle-reports/match',
          queryParameters: {'vehicleNo': vehicleNo});
      final data = res['data'];
      return data is Map<String, dynamic> ? VehicleReport.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id, String reason) async {
    try {
      await _api.postRaw('/vehicle-reports/${Uri.encodeComponent(id)}/remove',
          data: {'reason': reason});
    } catch (e) {
      throw Exception(_clean(e));
    }
  }

  Future<VehicleReportLink> link({bool regenerate = false}) async {
    try {
      final res = regenerate
          ? await _api.postRaw('/vehicle-reports/link/regenerate')
          : await _api.getRaw('/vehicle-reports/link');
      final data = res['data'];
      if (data is! Map) throw Exception('Unexpected response');
      return VehicleReportLink(
        path: (data['path'] ?? '').toString(),
        organisation: (data['organisation'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception(_clean(e));
    }
  }
}
