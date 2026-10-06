// ignore_for_file: uri_does_not_exist, creation_with_non_type

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/warehouse/presentation/controllers/warehouse_providers.dart';
import '../../features/gate_entry/presentation/gate_entry_page.dart';
import '../../features/reconciliation/presentation/reco_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/vendor/presentation/vendor_master_page.dart';
import '../auth/session_controller.dart';
import '../auth/user_role.dart';
import '../auth/session_state.dart';
import '../telemetry/telemetry.dart';
import '../ui/widgets/app_scaffold.dart';

/// Reports each screen the router shows to usage analytics (by route
/// pattern; see Telemetry.screen).
GoRouter _withScreenViews(Ref ref, GoRouter router) {
  if (!Telemetry.enabled) return router;
  // The delegate, not the route-information provider: it also hears the
  // location changes a redirect makes (sign-in landing on the dashboard).
  void report() {
    try {
      Telemetry.screen(router.routerDelegate.currentConfiguration.uri.toString());
    } catch (_) {
      // No configuration yet; the next change reports.
    }
  }

  router.routerDelegate.addListener(report);
  ref.onDispose(() => router.routerDelegate.removeListener(report));
  // The listener only hears changes: report the starting screen too.
  WidgetsBinding.instance.addPostFrameCallback((_) => report());
  return router;
}

final routerProvider = Provider<GoRouter>((ref) {
  return _withScreenViews(ref, GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);

      // While the stored token is being verified on startup/refresh, do not
      // bounce the user to /login. Once restore resolves to Authenticated or
      // Unauthenticated the router refresh listener will re-evaluate.
      if (session is SessionLoading) return null;

      final goingToLogin = state.matchedLocation == '/login';
      final authed = session is Authenticated;
      final role = session is Authenticated ? session.role : null;

      if (!authed && !goingToLogin) return '/login';
      if (authed && goingToLogin) return '/app/dashboard';
      if (role == UserRole.gateSecurity &&
          (state.matchedLocation == '/app/reconciliation' ||
              state.matchedLocation == '/app/reports')) {
        return '/app/dashboard';
      }
      // Vendor master is admin/manager only.
      if (state.matchedLocation == '/app/vendor-master' &&
          !role.isAdminOrWarehouseManager) {
        return '/app/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(
            selectedIndex: _indexFromLocation(state.matchedLocation),
            onSelect: (i) {
              switch (i) {
                case 0:
                  ref.invalidate(dashboardControllerProvider);
                  ref.invalidate(warehouseDashboardProvider);
                  ref.invalidate(warehouseReconciliationSummaryProvider);
                  ref.invalidate(warehouseManagerDashboardSummaryProvider);
                  ref.invalidate(warehouseManagerReconciliationsProvider);
                  context.go('/app/dashboard');
                  break;
                case 1:
                  context.go('/app/gate-entry');
                  break;
                case 2:
                  context.go('/app/reconciliation');
                  break;
                case 3:
                  context.go('/app/reports');
                  break;
                case 4:
                  context.go('/app/vendor-master');
                  break;
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/app/gate-entry',
            builder: (context, state) => const GateEntryPage(),
          ),
          GoRoute(
            path: '/app/reconciliation',
            builder: (context, state) => const RecoPage(),
          ),
          GoRoute(
            path: '/app/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/app/vendor-master',
            builder: (context, state) => const VendorMasterPage(),
          ),
        ],
      ),
    ],
  ));
});

int _indexFromLocation(String location) {
  if (location.startsWith('/app/gate-entry')) return 1;
  if (location.startsWith('/app/reconciliation')) return 2;
  if (location.startsWith('/app/reports')) return 3;
  if (location.startsWith('/app/vendor-master')) return 4;
  return 0;
}

/// Forces router refresh when session changes
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen<SessionState>(
      sessionControllerProvider,
      (_, __) => notifyListeners(),
    );
  }
  final Ref ref;
}


