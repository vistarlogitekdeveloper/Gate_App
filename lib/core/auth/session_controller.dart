import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_cleanup.dart';
import 'session_state.dart';
import 'user_role.dart';
import '../network/token_storage.dart';
import '../telemetry/telemetry.dart';
import '../../features/auth/domain/models/organization.dart';
import '../../features/auth/domain/models/user.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/data/dto/login_request.dart';
import '../../features/auth/data/auth_repository_impl.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  bool _isClearingSession = false;
  bool get isClearingSession => _isClearingSession;

  @override
  SessionState build() {
    // Attempt to restore session on initialization
    _restoreSession();
    return const SessionLoading();
  }

  Future<void> _restoreSession() async {
    final token = await ref.read(tokenStorageProvider).getToken();
    if (token != null) {
      try {
        final getCurrentUser = ref.read(getCurrentUserUseCaseProvider);
        final response = await getCurrentUser.execute();

        if (response.success && response.data != null) {
          // Refuse to restore a session whose user has no organization. A
          // legacy/unscoped JWT will pass /auth/me but any subsequent
          // write would land in NULL-org limbo on the backend. Force a
          // re-login instead so the user picks an org explicitly.
          final orgIdRaw = response.data!.organizationId;
          final orgId = orgIdRaw.trim();
          if (orgId.isEmpty) {
            await _clearSession();
            return;
          }
          final parsedRole = UserRole.fromApi(response.data!.role) ?? UserRole.admin;
          final organization = response.data!.organization ??
              Organization(
                id: orgId,
                code: '',
                name: '',
                isActive: true,
              );
          // Before the state change, so the screen it leads to is already theirs.
          _identify(response.data!, organization);
          state = Authenticated(
            user: response.data!,
            organization: organization,
            role: parsedRole,
          );
        } else {
          await _clearSession();
        }
      } catch (e) {
        await _clearSession();
      }
    } else {
      state = const Unauthenticated();
    }
  }

  Future<String?> login({
    required String organizationCode,
    required String identifier,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const SessionLoading();
    final loginUseCase = ref.read(loginUseCaseProvider);

    final response = await loginUseCase.execute(
      LoginRequest.fromIdentifier(
        organizationCode: organizationCode,
        identifier: identifier,
        password: password,
        rememberMe: rememberMe,
      ),
    );

    if (response.success && response.data != null) {
      final parsedRole = UserRole.fromApi(response.data!.role) ??
          UserRole.admin; // Fallback

      // Before the state change, so the screen it leads to is already theirs.
      _identify(response.data!.user, response.data!.organization);
      state = Authenticated(
        user: response.data!.user,
        organization: response.data!.organization,
        role: parsedRole,
      );

      // Confirm the session against the server by hitting /auth/me. This
      // fires regardless of which dashboard the user lands on and warms
      // the provider cache so subsequent watchers don't refetch. Errors
      // are intentionally swallowed: the login itself already succeeded,
      // a transient /auth/me failure shouldn't tear it down.
      ref.invalidate(currentUserProvider);
      ref.read(currentUserProvider.future).catchError((_) {
        return (state as Authenticated).user;
      });

      return null;
    } else {
      state = const Unauthenticated();
      final message = [
        response.error?.message,
        response.message,
      ].whereType<String>().map((e) => e.trim()).firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );

      if (_looksLikeNetworkIssue(message)) {
        return 'Unable to sign in right now. Please try again.';
      }

      return 'Invalid organization code, email, or password.';
    }
  }

  Future<void> logout() async {
    if (_isClearingSession || state is Unauthenticated) return;

    // Not awaited: sign-out never waits for analytics.
    Telemetry.signedOut();
    _isClearingSession = true;
    try {
      // Flip auth state first so widgets/router stop issuing authed requests
      // while provider cleanup is happening.
      state = const Unauthenticated();
      await ref.read(authRepositoryProvider).logout();
      scheduleOrgScopedStateClear(ref);
    } finally {
      _isClearingSession = false;
    }
  }

  /// Usage analytics: who this is (id, role and organisation code only).
  /// Fire and forget.
  void _identify(User user, Organization organization) => Telemetry.signedIn(
      userId: user.id, role: user.role, org: organization.code);

  bool get isAuthed => state is Authenticated;

  Authenticated? get authedOrNull =>
      state is Authenticated ? state as Authenticated : null;

  Future<void> invalidateSession() async {
    if (_isClearingSession) return;
    await _clearSession();
  }

  Future<void> _clearSession() async {
    if (_isClearingSession) return;

    // An expired session is a sign-out too (not awaited).
    if (state is Authenticated) Telemetry.signedOut();
    _isClearingSession = true;
    try {
      state = const Unauthenticated();
      await ref.read(tokenStorageProvider).deleteToken();
      scheduleOrgScopedStateClear(ref);
    } finally {
      _isClearingSession = false;
    }
  }

  bool _looksLikeNetworkIssue(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('timeout') ||
        normalized.contains('connection');
  }
}
