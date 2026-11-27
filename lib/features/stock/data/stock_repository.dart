import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/stock_models.dart';
import '../domain/stock_report.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.read(apiClientProvider)),
);

/// Is stock & dispatch on for this organisation, and what may this user do.
/// Null when signed out or the server cannot say (menus then stay hidden).
final stockSettingsProvider = FutureProvider<StockSettings?>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session is! Authenticated) return null;
  try {
    return await ref.read(stockRepositoryProvider).settings();
  } catch (_) {
    return null;
  }
});

/// One line of a dispatch: how much from which invoice line.
class DispatchLineInput {
  const DispatchLineInput({required this.line, required this.qty});
  final StockLine line;
  final double qty;

  Map<String, dynamic> toJson() => {
        'entryId': line.entryId,
        'poNumber': line.poNumber ?? '',
        'materialCode': line.materialCode ?? '',
        'qty': qty,
      };
}

class StockRepository {
  StockRepository(this._api);

  final ApiClient _api;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Map<String, dynamic> _map(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Unexpected response from the server.');
  }

  Future<StockSettings> settings() =>
      _call(() async => StockSettings.fromJson(_map(await _api.getRaw('/stock/settings'))));

  Future<void> setEnabled(bool enabled) =>
      _call(() async => _api.putRaw('/stock/settings', data: {'enabled': enabled}));

  /// open: count sheets with a balance left; otherwise all.
  Future<StockPage> list({bool open = true, String? search, int page = 1, int limit = 20}) => _call(() async {
        final res = await _api.getRaw('/stock', queryParameters: {
          'view': open ? 'open' : 'all',
          if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
          'page': '$page',
          'limit': '$limit',
        });
        final data = res['data'];
        final sheets = data is List
            ? data.whereType<Map<String, dynamic>>().map(StockSheet.fromJson).toList()
            : <StockSheet>[];
        final p = res['pagination'];
        int intOf(String k, int f) => p is Map && p[k] is num ? (p[k] as num).toInt() : f;
        return StockPage(
          sheets: sheets,
          page: intOf('page', page),
          totalPages: intOf('totalPages', sheets.isEmpty ? 0 : 1),
          total: intOf('total', sheets.length),
        );
      });

  /// Received / dispatched / balance of these count sheets (missing = no items).
  Future<Map<String, StockTotals>> summary(List<String> countSheetNos) => _call(() async {
        if (countSheetNos.isEmpty) return const {};
        final res = await _api.getRaw('/stock/summary', queryParameters: {'sheets': countSheetNos.join(',')});
        final data = res['data'];
        if (data is! Map) return const {};
        return {
          for (final e in data.entries)
            if (e.value is Map<String, dynamic>) e.key.toString(): StockTotals.fromJson(e.value as Map<String, dynamic>),
        };
      });

  /// A stock report: inward / outward between [from] and [to], or the
  /// balance as of [asOf] (now when null; [openOnly]: lines with stock left).
  Future<StockReportResult> report(
    StockReportKind kind, {
    DateTime? from,
    DateTime? to,
    DateTime? asOf,
    String? search,
    bool openOnly = false,
  }) =>
      _call(() async {
        final res = await _api.getRaw('/stock/reports/${kind.apiKind}', queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (asOf != null) 'asOf': asOf.toUtc().toIso8601String(),
          if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
          if (openOnly) 'open': '1',
        });
        final data = _map(res);
        final rows = data['rows'] is List
            ? (data['rows'] as List).whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        return StockReportResult(
          rows: rows,
          truncated: data['truncated'] == true,
          maxRows: data['maxRows'] is num ? (data['maxRows'] as num).toInt() : rows.length,
          asOf: DateTime.tryParse((data['asOf'] ?? '').toString())?.toLocal(),
        );
      });

  Future<StockSheet> countSheet(String countSheetNo) => _call(() async =>
      StockSheet.fromJson(_map(await _api.getRaw('/stock/count-sheets/${Uri.encodeComponent(countSheetNo)}'))));

  Future<DispatchResult> dispatch({
    required String challanNo,
    required String partyName,
    String? partyCode,
    required String vehicleNo,
    String? transporterName,
    String? driverContactNo,
    DateTime? documentDate,
    String? remarks,
    required List<DispatchLineInput> lines,
  }) =>
      _call(() async {
        final d = documentDate;
        final res = await _api.postRaw('/stock/dispatches', data: {
          'challanNo': challanNo,
          'partyName': partyName,
          if (partyCode != null && partyCode.isNotEmpty) 'partyCode': partyCode,
          'vehicleNo': vehicleNo,
          if (transporterName != null && transporterName.isNotEmpty) 'transporterName': transporterName,
          if (driverContactNo != null && driverContactNo.isNotEmpty) 'driverContactNo': driverContactNo,
          if (d != null)
            'documentDate': '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          'lines': lines.map((l) => l.toJson()).toList(),
        });
        final data = _map(res);
        return DispatchResult(
          id: (data['id'] ?? '').toString(),
          gateEntryNo: (data['gateEntryNo'] ?? '').toString(),
          challanNo: (data['challanNo'] ?? '').toString(),
        );
      });
}
