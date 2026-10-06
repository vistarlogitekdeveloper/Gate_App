import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/core/telemetry/telemetry.dart';

void main() {
  const uuid = '7f3c2a10-1b2c-4d5e-8f90-a1b2c3d4e5f6';

  test('screen names carry no record ids', () {
    expect(Telemetry.routePattern('/app/dashboard'), '/app/dashboard');
    expect(Telemetry.routePattern('/app/gate-entry?status=pending'), '/app/gate-entry');
    expect(Telemetry.routePattern('/gate-entries/$uuid/attachments?q=1'), '/gate-entries/:id/attachments');
    expect(Telemetry.routePattern('/gate-entries/42'), '/gate-entries/:id');
    expect(Telemetry.routePattern('https://api.example.com/api/v1/gate/gate-entries/42'),
        '/api/v1/gate/gate-entries/:id');
  });

  test('vehicle plates, challan and invoice numbers become :ref', () {
    expect(Telemetry.routePattern('/vehicles/MH12AB1234'), '/vehicles/:ref');
    expect(Telemetry.routePattern('/vehicles/MH-12-AB-1234'), '/vehicles/:ref');
    expect(Telemetry.routePattern('/vehicles/mh12ab1234/history'), '/vehicles/:ref/history');
    expect(Telemetry.routePattern('/challans/CH-0012'), '/challans/:ref');
    expect(Telemetry.routePattern('/challans/A12'), '/challans/:ref');
    expect(Telemetry.routePattern('/challans/INV%2F2024-25%2F0012'), '/challans/:ref');
    expect(Telemetry.routePattern('/gate-entries/GE-2026-000123'), '/gate-entries/:ref');
  });

  test('the gate journey is named from successful writes', () {
    expect(Telemetry.actionFor('POST', '/gate-entries'), 'gate_entry_created');
    expect(Telemetry.actionFor('PATCH', '/gate-entries/$uuid'), 'gate_entry_updated');
    expect(Telemetry.actionFor('POST', '/gate-entries/scan'), 'challan_scanned');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/attachments'), 'gate_entry_document_uploaded');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/gate-out'), 'gate_out_recorded');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/verify'), 'gate_entry_verified');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/approve'), 'gate_entry_approved');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/close'), 'gate_entry_closed');
    expect(Telemetry.actionFor('POST', '/gate-entries/$uuid/grn-exempt'), 'grn_exemption_changed');
    expect(Telemetry.actionFor('POST', '/grn'), 'grn_created');
    expect(Telemetry.actionFor('POST', '/reconciliations/$uuid/approve'), 'reconciliation_approved');
    expect(Telemetry.actionFor('POST', '/reconciliations/$uuid/close'), 'reconciliation_closed');
    expect(Telemetry.actionFor('POST', '/reconciliation/exceptions/$uuid/resolve'), 'reco_exception_resolved');
    expect(Telemetry.actionFor('post', '/sap/grns/import'), 'sap_grns_imported');
    expect(Telemetry.actionFor('POST', '/vendor-master'), 'vendor_created');
    expect(Telemetry.actionFor('PATCH', '/vendor-master/$uuid'), 'vendor_updated');
    expect(Telemetry.actionFor('DELETE', '/vendor-master/$uuid'), 'vendor_deleted');
    expect(Telemetry.actionFor('POST', '/auth/change-password'), 'password_changed');
  });

  test('reads, other methods, sign-in, audit logs and unknown paths are not reported', () {
    expect(Telemetry.actionFor('GET', '/gate-entries'), isNull);
    expect(Telemetry.actionFor('GET', '/gate-entries/$uuid'), isNull);
    expect(Telemetry.actionFor('GET', '/gate-entries/challan-unique'), isNull);
    expect(Telemetry.actionFor('PATCH', '/gate-entries/scan'), isNull);
    expect(Telemetry.actionFor('DELETE', '/gate-entries/$uuid'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/login'), isNull);
    expect(Telemetry.actionFor('POST', '/audit-logs'), isNull);
    expect(Telemetry.actionFor('POST', '/users'), isNull);
  });

  test('off without ET_APP_ID and ET_WRITE_KEY (the default build); calls are safe', () async {
    expect(Telemetry.enabled, isFalse);
    await Telemetry.init();
    Telemetry.screen('/app/dashboard');
    Telemetry.track('gate_entry_created');
    Telemetry.error('api_error', {'endpoint': '/gate-entries', 'method': 'POST'});
    Telemetry.signedIn(userId: 'u1', role: 'GATE_SECURITY', org: 'VST');
    Telemetry.signedOut();
  });

  test('the interceptor changes nothing about a request or its outcome', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid'))
      ..httpClientAdapter = _Answer()
      ..interceptors.add(TelemetryInterceptor());
    final ok = await dio.post<dynamic>('/gate-entries', data: {'x': 1});
    expect(ok.statusCode, 201);
    expect((ok.data as Map)['success'], isTrue);
    await expectLater(
      dio.post<dynamic>('/gate-entries/42/gate-out'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
  });
}

/// Answers 201 for a gate entry and 503 for anything else, with no network.
class _Answer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final created = options.path == '/gate-entries';
    return ResponseBody.fromString(
      jsonEncode({'success': created}),
      created ? 201 : 503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
