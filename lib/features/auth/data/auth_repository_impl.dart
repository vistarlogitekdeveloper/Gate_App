import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/models/auth_result.dart';
import '../domain/models/organization.dart';
import '../domain/models/user.dart';
import 'dto/login_request.dart';
import 'dto/user_response.dart';
import '../../../core/network/dio_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    dio: ref.read(dioProvider),
    apiClient: ref.read(apiClientProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl({
    required Dio dio,
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  @override
  Future<ApiResponse<AuthResult>> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return ApiResponse<AuthResult>(
          success: false,
          message: 'Unexpected login response format',
          error: ApiError(message: 'Unexpected login response format'),
        );
      }

      final envelope =
          body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body;
      final success = body['success'] as bool? ?? true;
      final message = (body['message'] ?? '').toString();

      if (!success) {
        final errorMap = body['error'] is Map<String, dynamic>
            ? body['error'] as Map<String, dynamic>
            : null;
        return ApiResponse<AuthResult>(
          success: false,
          message: message,
          error: errorMap != null
              ? ApiError.fromJson(errorMap)
              : ApiError(message: message.isNotEmpty ? message : 'Login failed'),
        );
      }

      final parsed = _parseLoginPayload(envelope, request);
      if (parsed.error != null) {
        return ApiResponse<AuthResult>(
          success: false,
          message: parsed.error!,
          error: ApiError(message: parsed.error!),
        );
      }

      await _tokenStorage.saveToken(parsed.token!, persist: parsed.rememberMe);
      return ApiResponse<AuthResult>(
        success: true,
        message: message,
        data: AuthResult(
          accessToken: parsed.token!,
          role: parsed.role!,
          user: parsed.user!,
          organization: parsed.organization!,
          rememberMe: parsed.rememberMe,
        ),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        final message = (responseData['message'] ??
                responseData['error']?['message'] ??
                e.message ??
                'Login failed')
            .toString();
        return ApiResponse<AuthResult>(
          success: false,
          message: message,
          error: ApiError(
            message: message,
            details: responseData['error'] ?? responseData,
          ),
        );
      }

      return ApiResponse<AuthResult>(
        success: false,
        message: e.message ?? 'Login failed',
        error: ApiError(message: e.message ?? 'Login failed'),
      );
    }
  }

  @override
  Future<ApiResponse<User>> getCurrentUser() async {
    final response = await _apiClient.get<UserResponse>(
      '/auth/me',
      fromJsonT: (json) => UserResponse.fromJson(json),
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      return ApiResponse<User>(
        success: true,
        message: response.message,
        data: User(
          id: data.id,
          organizationId: data.organizationId,
          employeeCode: data.employeeCode,
          fullName: data.fullName,
          email: data.email,
          role: data.role,
          isActive: data.isActive,
          lastLoginAt: data.lastLoginAt,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
          organization: data.organization == null
              ? null
              : Organization(
                  id: data.organization!.id,
                  code: data.organization!.code,
                  name: data.organization!.name,
                  isActive: data.organization!.isActive,
                  createdAt: data.organization!.createdAt,
                  updatedAt: data.organization!.updatedAt,
                ),
        ),
      );
    }

    return ApiResponse<User>(
      success: false,
      message: response.message,
      error: response.error,
    );
  }

  @override
  Future<ApiResponse<void>> changePassword(
      {required String currentPassword, required String newPassword}) async {
    final response = await _apiClient.post<void>(
      '/auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );

    if (response.success) {
      return ApiResponse<void>(
        success: true,
        message: response.message,
      );
    }

    return ApiResponse<void>(
      success: false,
      message: response.message,
      error: response.error,
    );
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.deleteToken();
  }
}

class _ParsedLoginPayload {
  final String? token;
  final String? role;
  final User? user;
  final Organization? organization;
  final bool rememberMe;
  final String? error;

  const _ParsedLoginPayload({
    this.token,
    this.role,
    this.user,
    this.organization,
    this.rememberMe = false,
    this.error,
  });
}

_ParsedLoginPayload _parseLoginPayload(
  Map<String, dynamic> data,
  LoginRequest request,
) {
  final user = data['user'] is Map<String, dynamic>
      ? data['user'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final token = (data['token'] ?? data['accessToken'] ?? '').toString();
  final rememberMe = data['rememberMe'] as bool? ?? request.rememberMe;
  final userId = (user['id'] ?? data['userId'] ?? '').toString();
  final employeeCode = _nullableString(
    user['employeeCode'] ?? user['employee_code'] ?? data['username'],
  );
  final fullName = (user['fullName'] ?? user['full_name'] ?? employeeCode ?? '')
      .toString();
  final email = (user['email'] ?? '').toString();
  final role = (user['role'] ?? data['role'] ?? '').toString();
  final organizationData = data['organization'] is Map<String, dynamic>
      ? data['organization'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final organizationId =
      (organizationData['id'] ?? user['organizationId'] ?? '').toString();
  final organizationCode = (organizationData['code'] ?? request.organizationCode)
      .toString();
  final organizationName =
      (organizationData['name'] ?? organizationCode).toString();
  final organizationIsActive = organizationData['isActive'] as bool?;

  if (token.isEmpty) {
    return const _ParsedLoginPayload(error: 'Login token missing in response');
  }

  if (userId.isEmpty || role.isEmpty) {
    return const _ParsedLoginPayload(
      error: 'Login response is missing user details',
    );
  }

  // Defensive tenant-mismatch guard.
  //
  // If a user types organizationCode="DEFAULT" but the server authenticates
  // them into organizationCode="TEST" (as observed in prod on 2026-09-15),
  // every subsequent tenant-scoped call — /vendor-master, /gate-entries,
  // /reports/* — silently operates against the wrong org's data. The most
  // visible symptom is empty vendor/entry lists; the more dangerous symptom
  // is a guard entering a real gate entry that lands in a test tenant.
  //
  // Refuse to complete login if the codes don't match (case-insensitively,
  // trimmed) so the user knows their credentials don't belong to the org
  // they asked to sign into. This is a server bug (the login handler should
  // reject or return the requested org), but until it's fixed the client
  // must surface it instead of silently accepting a different tenant.
  final requestedCode = request.organizationCode.trim().toUpperCase();
  final returnedCode = organizationCode.trim().toUpperCase();
  if (requestedCode.isNotEmpty &&
      returnedCode.isNotEmpty &&
      requestedCode != returnedCode) {
    return _ParsedLoginPayload(
      error:
          'You tried to sign in to organization "${request.organizationCode}", '
          'but the server authenticated you into "$organizationCode" '
          '($organizationName). This means these credentials do not belong to '
          '"${request.organizationCode}". Ask your admin for credentials that '
          'match your organization, or contact the backend team if you believe '
          'this is a login bug.',
    );
  }

  return _ParsedLoginPayload(
    token: token,
    role: role,
    rememberMe: rememberMe,
    organization: Organization(
      id: organizationId,
      code: organizationCode,
      name: organizationName,
      isActive: organizationIsActive ?? true,
      createdAt: _parseDateTime(organizationData['createdAt']),
      updatedAt: _parseDateTime(organizationData['updatedAt']),
    ),
    user: User(
      id: userId,
      organizationId: organizationId,
      employeeCode: employeeCode,
      fullName: fullName,
      email: email,
      role: role,
      isActive: user['isActive'] as bool? ?? true,
      lastLoginAt: _parseDateTime(user['lastLoginAt']),
      createdAt: _parseDateTime(user['createdAt']),
      updatedAt: _parseDateTime(user['updatedAt']),
    ),
  );
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
