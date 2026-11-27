import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/vtt_models.dart';

final vttRepositoryProvider = Provider<VttRepository>(
  (ref) => VttRepository(ref.read(apiClientProvider)),
);

/// Is vehicle tracking on for this organisation, and what may this user do.
/// Null when signed out or the server cannot say (the menu then stays hidden).
final vttSettingsProvider = FutureProvider<VttSettings?>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session is! Authenticated) return null;
  try {
    return await ref.read(vttRepositoryProvider).settings();
  } catch (_) {
    return null;
  }
});

/// Vehicle tracking: setup (admin), live board, recording, trips.
class VttRepository {
  VttRepository(this._api);

  final ApiClient _api;
  static const _base = '/vehicle-tracking';

  static Exception _clean(Object e) => Exception(e.toString().replaceFirst('Exception: ', ''));

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw _clean(e);
    }
  }

  static Map<String, dynamic> _map(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Unexpected response from the server.');
  }

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> res) {
    final data = res['data'];
    return data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];
  }

  // ── settings ──
  Future<VttSettings> settings() =>
      _call(() async => VttSettings.fromJson(_map(await _api.getRaw('$_base/settings'))));

  Future<void> saveSettings({bool? enabled, int? reviseWindowHours, int? amberPercent}) => _call(() async {
        await _api.putRaw('$_base/settings', data: {
          if (enabled != null) 'enabled': enabled,
          if (reviseWindowHours != null) 'reviseWindowHours': reviseWindowHours,
          if (amberPercent != null) 'amberPercent': amberPercent,
        });
      });

  // ── checkpoints ──
  Future<List<VttTemplate>> templates() =>
      _call(() async => _rows(await _api.getRaw('$_base/templates')).map(VttTemplate.fromJson).toList());

  Future<void> applyTemplate(String key, {bool replace = false, String? from, String? to}) => _call(() async {
        await _api.postRaw('$_base/templates/${Uri.encodeComponent(key)}/apply', data: {
          'replace': replace,
          if (from != null || to != null) 'sites': {'from': from, 'to': to},
        });
      });

  Future<List<VttCheckpoint>> checkpoints() =>
      _call(() async => _rows(await _api.getRaw('$_base/checkpoints')).map(VttCheckpoint.fromJson).toList());

  Map<String, dynamic> _checkpointBody({
    String? name,
    String? kind,
    String? site,
    bool? isMandatory,
    bool? isActive,
    String? autoSource,
    bool setAutoSource = false,
  }) =>
      {
        if (name != null) 'name': name,
        if (kind != null) 'kind': kind,
        if (site != null) 'site': site,
        if (isMandatory != null) 'isMandatory': isMandatory,
        if (isActive != null) 'isActive': isActive,
        if (setAutoSource) 'autoSource': autoSource,
      };

  Future<void> createCheckpoint({
    required String name,
    required String kind,
    String? site,
    required bool isMandatory,
    String? autoSource,
  }) =>
      _call(() async {
        await _api.postRaw('$_base/checkpoints',
            data: _checkpointBody(
                name: name,
                kind: kind,
                site: site ?? '',
                isMandatory: isMandatory,
                autoSource: autoSource,
                setAutoSource: true));
      });

  Future<void> updateCheckpoint(
    String id, {
    String? name,
    String? kind,
    String? site,
    bool? isMandatory,
    bool? isActive,
    String? autoSource,
    bool setAutoSource = false,
  }) =>
      _call(() async {
        await _api.patchRaw('$_base/checkpoints/${Uri.encodeComponent(id)}',
            data: _checkpointBody(
                name: name,
                kind: kind,
                site: site,
                isMandatory: isMandatory,
                isActive: isActive,
                autoSource: autoSource,
                setAutoSource: setAutoSource));
      });

  /// -> true when deleted, false when switched off (it is on past trips).
  Future<bool> deleteCheckpoint(String id) => _call(() async {
        final res = await _api.deleteRaw('$_base/checkpoints/${Uri.encodeComponent(id)}');
        final data = res['data'];
        return data is Map && data['deleted'] == true;
      });

  Future<void> reorderCheckpoints(List<String> ids) =>
      _call(() async => _api.postRaw('$_base/checkpoints/reorder', data: {'ids': ids}));

  Future<void> setCheckpointUsers(String id, List<String> userIds) => _call(() async {
        await _api.putRaw('$_base/checkpoints/${Uri.encodeComponent(id)}/users', data: {'userIds': userIds});
      });

  /// categoryId null = every vehicle; minutes null = no target.
  Future<void> setTargets(String id, Map<String?, int?> targets) => _call(() async {
        await _api.putRaw('$_base/checkpoints/${Uri.encodeComponent(id)}/targets', data: {
          'targets': [
            for (final e in targets.entries) {'categoryId': e.key, 'minutes': e.value},
          ],
        });
      });

  Future<List<VttUser>> users() =>
      _call(() async => _rows(await _api.getRaw('$_base/users')).map(VttUser.fromJson).toList());

  // ── vehicles and categories ──
  Future<List<VttCategory>> categories() =>
      _call(() async => _rows(await _api.getRaw('$_base/categories')).map(VttCategory.fromJson).toList());

  Future<void> saveCategory({String? id, required String name, String? description, bool? isActive}) =>
      _call(() async {
        final body = {
          'name': name,
          'description': description ?? '',
          if (isActive != null) 'isActive': isActive,
        };
        if (id == null) {
          await _api.postRaw('$_base/categories', data: body);
        } else {
          await _api.patchRaw('$_base/categories/${Uri.encodeComponent(id)}', data: body);
        }
      });

  Future<List<VttVehicle>> vehicles() =>
      _call(() async => _rows(await _api.getRaw('$_base/vehicles')).map(VttVehicle.fromJson).toList());

  Future<void> saveVehicle({
    String? id,
    required String vehicleNo,
    String? categoryId,
    String? capacity,
    String? transporter,
    double? hoursPerDay,
    bool? isActive,
  }) =>
      _call(() async {
        final body = {
          'vehicleNo': vehicleNo,
          'categoryId': categoryId,
          'capacity': capacity ?? '',
          'transporter': transporter ?? '',
          'hoursPerDay': hoursPerDay,
          if (isActive != null) 'isActive': isActive,
        };
        if (id == null) {
          await _api.postRaw('$_base/vehicles', data: body);
        } else {
          await _api.patchRaw('$_base/vehicles/${Uri.encodeComponent(id)}', data: body);
        }
      });

  // ── recording and trips ──
  Future<VttBoard> board() => _call(() async => VttBoard.fromJson(_map(await _api.getRaw('$_base/board'))));

  Future<VttTrip> record({required String vehicleId, required String checkpointId, String? remark}) =>
      _call(() async => VttTrip.fromJson(_map(await _api.postRaw('$_base/record', data: {
            'vehicleId': vehicleId,
            'checkpointId': checkpointId,
            if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
          }))));

  Future<VttTripPage> trips({String? status, String? search, DateTime? from, DateTime? to, int page = 1, int limit = 25}) =>
      _call(() async {
        final res = await _api.getRaw('$_base/trips', queryParameters: {
          if (status != null) 'status': status,
          if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'page': '$page',
          'limit': '$limit',
        });
        final trips = _rows(res).map(VttTrip.fromJson).toList();
        final p = res['pagination'];
        int intOf(String key, int fallback) => p is Map && p[key] is num ? (p[key] as num).toInt() : fallback;
        return VttTripPage(
          trips: trips,
          page: intOf('page', page),
          totalPages: intOf('totalPages', trips.isEmpty ? 0 : 1),
          total: intOf('total', trips.length),
        );
      });

  Future<VttTrip> trip(String id) =>
      _call(() async => VttTrip.fromJson(_map(await _api.getRaw('$_base/trips/${Uri.encodeComponent(id)}'))));

  Future<VttTrip> revise(String entryId, {required DateTime at, required String reason}) =>
      _call(() async => VttTrip.fromJson(_map(await _api.postRaw(
            '$_base/entries/${Uri.encodeComponent(entryId)}/revise',
            data: {'at': at.toUtc().toIso8601String(), 'reason': reason},
          ))));

  /// action: complete / cancel.
  Future<VttTrip> closeTrip(String tripId, {required String action, required String reason}) =>
      _call(() async => VttTrip.fromJson(_map(await _api.postRaw(
            '$_base/trips/${Uri.encodeComponent(tripId)}/close',
            data: {'action': action, 'reason': reason},
          ))));
}
