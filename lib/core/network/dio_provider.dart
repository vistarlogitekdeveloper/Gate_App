import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../telemetry/telemetry.dart';
import 'token_storage.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(dioProvider));
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.baseUrl,
    // 30s was way too long — a flaky network kept spinners up for half a
    // minute, which users perceived as the app hanging. 15s is enough for
    // the slowest endpoints and surfaces failures fast.
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
  ));
  // BackgroundTransformer decodes JSON responses on a background isolate so
  // megabyte-sized payloads don't stall the UI thread.
  dio.transformer = BackgroundTransformer();

  if (Env.isDebug) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
      error: true,
    ));
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final session = ref.read(sessionControllerProvider);
      final sessionController = ref.read(sessionControllerProvider.notifier);
      final tokenStorage = ref.read(tokenStorageProvider);
      final token =
          tokenStorage.cachedToken ?? await tokenStorage.getToken();
      final isAuthRequest = options.path.startsWith('/auth/');

      if (!isAuthRequest &&
          (sessionController.isClearingSession ||
              session is Unauthenticated ||
              token == null ||
              token.isEmpty)) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Request cancelled because the session is inactive.',
          ),
        );
      }

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (e, handler) async {
      final status = e.response?.statusCode;
      final isAuthError = status == 401;

      if (isAuthError) {
        await ref.read(sessionControllerProvider.notifier).invalidateSession();
      }

      return handler.next(e);
    },
  ));

  // Usage analytics: named actions and failed calls. Changes nothing about
  // the request or its handling (lib/core/telemetry/telemetry.dart).
  dio.interceptors.add(TelemetryInterceptor());

  return dio;
});
