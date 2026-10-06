import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:vistar_event_tracker/vistar_event_tracker.dart'
    show EventType, TrackerConfig, VistarEventTracker, VistarEvents;

import '../config/env.dart';

/// Usage analytics for the Gate app, sent to the in-house event tracker and
/// read in the Platform Console under Analytics > Event tracker.
///
/// Off unless the build is given both:
///   --dart-define=ET_APP_ID=gate_app --dart-define=ET_WRITE_KEY=wk_...
/// (register the app in the Platform Console, Settings > Event tracker; the
/// write key only lets a client append events, so it may ship in the app).
/// Optional --dart-define=ET_BASE_URL=... sends a test build's events
/// somewhere other than the API host the app uses (by default, the host of
/// Env.baseUrl, so a UAT build reports to UAT).
///
/// What is sent:
///   * screen views, by route pattern (ids and references replaced:
///     `/gate-entries/:id`, `/vehicles/:ref`)
///   * sign-in / sign-out; the user as `gate:<user id>`, with their role and
///     organisation code as traits
///   * named actions from successful API writes (see [_actions]):
///     `gate_entry_created`, `gate_out_recorded`, `challan_scanned`, ...
///   * failed API calls (5xx or no connection), and client errors by TYPE
///     only (never the message, which can quote a server reply)
/// Never sent: request or response bodies, names, phone numbers, emails,
/// vehicle plates, driver or vendor names, challan / invoice numbers, photos,
/// recognised (OCR) text or any other record content. The camera, QR and
/// challan-scanning flows are not touched: only the resulting successful API
/// call is counted.
///
/// NEVER IN THE WAY OF WORK. Nothing here is awaited by a screen, a gate
/// entry, a sign-in or a sign-out; start-up waits at most [_initBudget];
/// every call swallows its own failures; the queue is capped at [_maxQueue]
/// events (oldest dropped) and lives in shared preferences; sending is in the
/// background with the SDK's backoff.
abstract final class Telemetry {
  static const _appId = String.fromEnvironment('ET_APP_ID');
  static const _writeKey = String.fromEnvironment('ET_WRITE_KEY');
  static const _baseUrlOverride = String.fromEnvironment('ET_BASE_URL');
  static const _appVersion = String.fromEnvironment('APP_VERSION');
  static const _initBudget = Duration(seconds: 2);
  static const _maxQueue = 200;

  static bool get enabled => _appId != '' && _writeKey != '';

  static VistarEventTracker get _t => VistarEventTracker.instance;
  static bool get _on => enabled && _t.isInitialized;

  static String? _lastScreen;
  static Future<void>? _resetting;

  static String get _origin {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    final u = Uri.parse(Env.baseUrl);
    return '${u.scheme}://${u.authority}';
  }

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await _t
          .init(TrackerConfig(
            appId: _appId,
            writeKey: _writeKey,
            baseUrl: _origin,
            appVersion: _appVersion.isEmpty ? null : _appVersion,
            maxQueueSize: _maxQueue,
            // The SDK's own error capture sends the exception message and
            // stack, and a message here can quote a server reply (a challan
            // number, a vehicle). [_captureErrors] sends the type only.
            autoCaptureErrors: false,
          ))
          .timeout(_initBudget);
      _captureErrors();
    } catch (_) {
      // Analytics must never stop the app from starting.
    }
  }

  /// Client errors, by type only. Chains to whatever handled them before, so
  /// the app's own error handling is unchanged.
  static void _captureErrors() {
    if (!_on) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _clientError(details.exception, fatal: false, library: details.library);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _clientError(error, fatal: true);
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  static void _clientError(Object e, {required bool fatal, String? library}) {
    try {
      error(VistarEvents.clientError, {
        'error': e.runtimeType.toString(),
        if (library != null) 'library': library,
        'fatal': fatal,
      });
    } catch (_) {}
  }

  /// A screen, by its route pattern. Repeats are dropped.
  static void screen(String location) {
    if (!_on) return;
    final name = routePattern(location);
    if (name == _lastScreen) return;
    _lastScreen = name;
    _guard(() => _t.screen(name));
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_on) _guard(() => _t.track(name, properties: properties));
  }

  static void error(String name, Map<String, dynamic> properties) {
    if (_on) _guard(() => _t.track(name, properties: properties, type: EventType.error));
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // Analytics never surfaces as an app error.
    }
  }

  /// Fire and forget: the sign-in never waits for analytics.
  static void signedIn({required String userId, String? role, String? org}) {
    if (!_on || userId.isEmpty) return;
    unawaited(() async {
      try {
        // A sign-out just before (a gate tablet changing shifts) resets the
        // identity; let it finish so this one is not wiped by it.
        await _resetting?.timeout(const Duration(seconds: 5), onTimeout: () {});
        await _t.identify('gate:$userId', traits: {
          if (role != null && role.isNotEmpty) 'role': role,
          if (org != null && org.isNotEmpty) 'org': org,
        });
      } catch (_) {}
    }());
  }

  /// Fire and forget: the sign-out never waits for analytics (the SDK's reset
  /// sends what is queued first, which can take a while on a poor network).
  static void signedOut() {
    _lastScreen = null;
    if (!_on) return;
    try {
      _resetting = _t.reset().catchError((Object _) {});
    } catch (_) {}
  }

  /// `/gate-entries/9f3c...-.../attachments?x=1` -> `/gate-entries/:id/attachments`.
  ///
  /// Any segment with a digit in it is replaced: numbers and uuids become
  /// `:id`; everything else with a digit (vehicle plates such as MH12AB1234,
  /// challan / invoice / gate entry numbers) becomes `:ref`. The query string
  /// is dropped. An API version segment (`v1`) is kept.
  static String routePattern(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    return path.split('/').map((s) {
      if (s.isEmpty) return s;
      if (RegExp(r'^\d+$').hasMatch(s)) return ':id';
      if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-', caseSensitive: false).hasMatch(s)) return ':id';
      if (RegExp(r'^v\d{1,2}$').hasMatch(s)) return s;
      if (RegExp(r'\d').hasMatch(s)) return ':ref';
      return s;
    }).join('/');
  }

  /// Successful API writes worth naming, by method and path (ids stripped).
  /// First match wins; anything else (reads, sign-in, the app's own audit-log
  /// writes, unknown paths) is not reported.
  static final List<(String, RegExp, String)> _actions = [
    ('POST', RegExp(r'^/gate-entries$'), 'gate_entry_created'),
    ('PATCH', RegExp(r'^/gate-entries/:(id|ref)$'), 'gate_entry_updated'),
    ('POST', RegExp(r'^/gate-entries/scan$'), 'challan_scanned'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/attachments$'), 'gate_entry_document_uploaded'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/gate-out$'), 'gate_out_recorded'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/verify$'), 'gate_entry_verified'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/approve$'), 'gate_entry_approved'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/close$'), 'gate_entry_closed'),
    ('POST', RegExp(r'^/gate-entries/:(id|ref)/grn-exempt$'), 'grn_exemption_changed'),
    ('POST', RegExp(r'^/grn$'), 'grn_created'),
    ('POST', RegExp(r'^/reconciliations/:(id|ref)/approve$'), 'reconciliation_approved'),
    ('POST', RegExp(r'^/reconciliations/:(id|ref)/close$'), 'reconciliation_closed'),
    ('POST', RegExp(r'^/reconciliation/exceptions/:(id|ref)/resolve$'), 'reco_exception_resolved'),
    ('POST', RegExp(r'^/sap/grns/import$'), 'sap_grns_imported'),
    ('POST', RegExp(r'^/vendor-master$'), 'vendor_created'),
    ('PATCH', RegExp(r'^/vendor-master/:(id|ref)$'), 'vendor_updated'),
    ('DELETE', RegExp(r'^/vendor-master/:(id|ref)$'), 'vendor_deleted'),
    ('POST', RegExp(r'^/auth/change-password$'), 'password_changed'),
  ];

  /// The business event for a successful API call, or null.
  static String? actionFor(String method, String path) {
    final pattern = routePattern(path);
    for (final (m, re, name) in _actions) {
      if (m == method.toUpperCase() && re.hasMatch(pattern)) return name;
    }
    return null;
  }
}

/// Reports named actions and failed calls from the app's one HTTP client
/// (dioProvider). Adds no headers and changes nothing about the request or
/// its handling.
class TelemetryInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // This client uses Dio's default validateStatus, so only a 2xx arrives
    // here; a 2xx whose envelope says `success: false` did not happen either.
    final code = response.statusCode ?? 0;
    if (Telemetry.enabled && code >= 200 && code < 300) {
      String? name;
      try {
        final body = response.data;
        final refused = body is Map && body['success'] == false;
        final o = response.requestOptions;
        if (!refused) name = Telemetry.actionFor(o.method, o.path);
      } catch (_) {}
      if (name != null) Telemetry.track(name);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Telemetry.enabled) {
      try {
        final status = err.response?.statusCode;
        // A 4xx is a decision the server made, and a cancel is the app's own
        // (a screen left, or a request refused while signed out).
        if ((status == null || status >= 500) && err.type != DioExceptionType.cancel) {
          Telemetry.error('api_error', {
            'endpoint': Telemetry.routePattern(err.requestOptions.path),
            'method': err.requestOptions.method,
            if (status != null) 'status': status,
            'kind': err.type.name,
          });
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
