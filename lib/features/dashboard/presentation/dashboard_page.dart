import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import 'controllers/dashboard_controller.dart';
import '../domain/entities/dashboard_metrics.dart';
import '../../auth/domain/usecases/get_current_user_usecase.dart';
import '../../auth/domain/models/user.dart';
import '../../auth/presentation/change_password_page.dart';
import '../../../core/ui/auto_refresh.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/dashboard_chart.dart';
import '../../../core/ui/widgets/logout_action.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/stat_card.dart';
import '../../../core/ui/widgets/theme_toggle_button.dart';
import '../../sap/presentation/widgets/grn_import_card.dart';
import '../../gate_entry/presentation/controllers/gate_entry_controller.dart';
import '../../gate_entry/presentation/gate_entry_detail_page.dart';
import '../../../core/ui/widgets/progress_dialog.dart';

// --- Warehouse imports for Exec/Manager dashboards ---
import '../../warehouse/presentation/controllers/warehouse_providers.dart';
import '../../warehouse/domain/models/warehouse_reconciliation.dart';
import '../../warehouse/domain/models/reconciliation_dashboard.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select just the role from the session — rebuilding the whole
    // DashboardPage every time any session field changes was burning frames
    // on every auth heartbeat / token refresh.
    final role = ref.watch(
      sessionControllerProvider
          .select((s) => s is Authenticated ? s.role : null),
    );

    final isManager = role == UserRole.warehouseManager ||
        role == UserRole.whMgr ||
        role == UserRole.admin;
    final isExecutive = role == UserRole.warehouseExecutive;

    String title = 'Operations Dashboard';
    if (isManager) title = 'Manager Dashboard';
    if (isExecutive) title = 'Warehouse Dashboard';

    // Only auto-refresh the providers the *currently rendered* dashboard
    // actually reads. The old list also invalidated providers consumed by
    // sibling dashboards (and a duplicate of one that's pulled in
    // transitively), which spawned redundant network calls and heavy
    // main-isolate work — that's what made the page feel frozen between
    // ticks. Manual refresh button is still available for on-demand pulls.
    final List<ProviderOrFamily> watchedProviders;
    if (isManager) {
      watchedProviders = [
        warehouseManagerDashboardSummaryProvider,
        warehouseManagerAdminKpiProvider,
        reconciliationDashboardProvider,
      ];
    } else if (isExecutive) {
      watchedProviders = [
        warehouseDashboardProvider,
        warehouseReconciliationSummaryProvider,
      ];
    } else {
      watchedProviders = [dashboardControllerProvider, currentUserProvider];
    }

    return AutoRefresh(
      providers: watchedProviders,
      interval: const Duration(minutes: 5),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Row(
            children: [
              const RibbonAccentBar(height: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(title, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            if (role.isAdminOrWarehouseManager)
              TextButton.icon(
                onPressed: () => context.go('/app/vendor-master'),
                icon: const Icon(Icons.store_rounded),
                label: Text(
                  isMobile(context) ? '' : 'Vendors',
                ),
              ),
            if (role.isAdminOrWarehouseManager)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_reset),
                label: Text(
                  isMobile(context) ? '' : 'Change Password',
                ),
              ),
            IconButton(
              tooltip: 'Refresh now',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                for (final p in watchedProviders) {
                  ref.invalidate(p);
                }
              },
            ),
            const ThemeToggleButton(),
            const LogoutAction(),
            const SizedBox(width: 8),
          ],
        ),
        body: isManager
            ? _ManagerDashboard(isMob: isMobile(context))
            : isExecutive
                ? _ExecutiveDashboard(isMob: isMobile(context))
                : _SecurityDashboard(isMob: isMobile(context)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1) SECURITY DASHBOARD
// ---------------------------------------------------------------------------

class _SecurityDashboard extends ConsumerWidget {
  final bool isMob;
  const _SecurityDashboard({required this.isMob});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState =
        ref.watch(sessionControllerProvider.notifier).authedOrNull;
    final metricsAsync = ref.watch(dashboardControllerProvider);
    final userAsync = ref.watch(currentUserProvider);

    return metricsAsync.when(
      data: (metrics) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(dashboardControllerProvider.future),
              ref.refresh(currentUserProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SectionHeader(
                title: 'Welcome back, ${_displayName(userAsync, sessionState)}',
                subtitle:
                    'Role: ${_displayRole(userAsync, sessionState)} - ${_displayLogin(userAsync, sessionState)}',
              ),
              if (metrics.overdueGateOut.isNotEmpty) ...[
                const SizedBox(height: 8),
                _OverdueGateOutAlert(metrics: metrics),
                const SizedBox(height: 8),
              ],
              Builder(
                builder: (context) {
                  final cards = <Widget>[
                    StatCard(
                      title: 'Gate In',
                      value: metrics.gateInCount.toString(),
                      icon: Icons.login,
                      color: Colors.indigo,
                    ),
                    StatCard(
                      title: 'Gate Out',
                      value: metrics.gateOutCount.toString(),
                      icon: Icons.logout,
                      color: Colors.deepOrange,
                    ),
                    StatCard(
                      title: "Today's Entries",
                      value: metrics.totalGateEntriesToday.toString(),
                      icon: Icons.today,
                      color: Colors.teal,
                    ),
                    StatCard(
                      title: 'My Entries',
                      value: metrics.myCreatedToday.toString(),
                      icon: Icons.person,
                      color: Colors.purple,
                    ),
                    StatCard(
                      title: 'Pending Gate Out',
                      value: metrics.pendingGateOut.toString(),
                      icon: Icons.local_shipping,
                      color: Colors.amber.shade800,
                    ),
                  ];

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isMob ? 200 : 260,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isMob ? 1.2 : 2.2,
                    ),
                    itemCount: cards.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) => cards[index],
                  );
                },
              ),
              const SizedBox(height: 24),
              _TatCard(metrics: metrics),
              const SizedBox(height: 32),
              _buildActivityChart(context, metrics, isMob),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
      loading: () => ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SkeletonLoader(width: 250, height: 40),
          SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: SkeletonLoader(width: double.infinity, height: 120)),
            SizedBox(width: 16),
            Expanded(
                child: SkeletonLoader(width: double.infinity, height: 120)),
          ]),
          SizedBox(height: 32),
          SkeletonLoader(width: double.infinity, height: 300),
        ],
      ),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildActivityChart(
      BuildContext context, DashboardMetrics metrics, bool isMob) {
    if (metrics.recentActivity.isEmpty) return const SizedBox.shrink();
    final List<ChartBarData> chartData =
        metrics.recentActivity.map<ChartBarData>((a) {
      return ChartBarData(
        label: a.day,
        value: a.entriesCount.toDouble(),
      );
    }).toList();
    return DashboardChart(
      title: 'Gate Entry Activity (Last 7 Days)',
      data: chartData,
      height: isMob ? 260 : 350,
    );
  }

  String _displayName(AsyncValue<User> userAsync, Authenticated? session) {
    return userAsync.when(
      data: (user) {
        if (user.fullName.isNotEmpty) return user.fullName;
        if (session != null && session.fullName.isNotEmpty) return session.fullName;
        if (user.email.isNotEmpty) return user.email;
        return 'User';
      },
      loading: () => session?.fullName.isNotEmpty == true ? session!.fullName : 'User',
      error: (_, __) => session?.fullName.isNotEmpty == true ? session!.fullName : 'User',
    );
  }

  String _displayRole(AsyncValue<User> userAsync, Authenticated? session) {
    return userAsync.when(
      data: (user) => user.role.isNotEmpty
          ? (UserRole.fromApi(user.role)?.label ?? user.role)
          : (session?.role.label ?? 'Operator'),
      loading: () => session?.role.label ?? 'Operator',
      error: (_, __) => session?.role.label ?? 'Operator',
    );
  }

  String _displayLogin(AsyncValue<User> userAsync, Authenticated? session) {
    return userAsync.when(
      data: (user) {
        final parts = <String>[];
        if (user.employeeCode?.isNotEmpty == true) {
          parts.add(user.employeeCode!);
        }
        if (user.email.isNotEmpty) parts.add(user.email);
        if (parts.isNotEmpty) return 'Logged in as ${parts.join(' • ')}';
        return 'Logged in';
      },
      loading: () => 'Logged in',
      error: (_, __) => 'Logged in',
    );
  }
}

// ---------------------------------------------------------------------------
// EXECUTIVE & MANAGER DASHBOARDS (merged from warehouse_dashboard_page)
// ---------------------------------------------------------------------------

class _ExecutiveDashboard extends ConsumerWidget {
  final bool isMob;

  const _ExecutiveDashboard({required this.isMob});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(warehouseDashboardProvider);
    final recSummary = ref.watch(warehouseReconciliationSummaryProvider);

    return metrics.when(
      loading: () => ListView(
        padding:
            EdgeInsets.symmetric(horizontal: isMob ? 16 : 24, vertical: 16),
        children: const [
          SkeletonLoader(width: 220, height: 28),
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 120),
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 120),
        ],
      ),
      error: (e, _) => Center(child: Text('Failed to load dashboard: $e')),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(warehouseDashboardProvider.future),
              ref.refresh(warehouseReconciliationSummaryProvider.future),
            ]);
          },
          child: ListView(
          padding:
              EdgeInsets.symmetric(horizontal: isMob ? 16 : 24, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Today Overview',
              subtitle: 'Track pending GRNs and incoming entries quickly.',
              trailing: TextButton.icon(
                onPressed: () => context.go('/app/gate-entry'),
                icon: const Icon(Icons.list_alt),
                label: const Text('View Pending GRNs'),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Pending GRNs',
                  value: data.pendingGrnCount.toString(),
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                  width: isMob ? double.infinity : 220,
                ),
                _StatCard(
                  title: "Today's Entries",
                  value: data.todaysEntries.toString(),
                  icon: Icons.local_shipping,
                  color: Colors.indigo,
                  width: isMob ? double.infinity : 220,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Reconciliation Snapshot (Today)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReconciliationSection(context, recSummary, isMob),
          ],
          ),
        );
      },
    );
  }

  Widget _buildReconciliationSection(
    BuildContext context,
    AsyncValue<WarehouseReconciliationSummary> summary,
    bool isMob,
  ) {
    return summary.when(
      loading: () => const SkeletonLoader(width: double.infinity, height: 110),
      error: (e, _) => Text(
        'Failed to load reconciliation: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (data) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatCard(
            title: 'Matched',
            value: data.matched.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
            width: isMob ? double.infinity : 180,
          ),
          _StatCard(
            title: 'Pending',
            value: data.pending.toString(),
            icon: Icons.hourglass_bottom,
            color: Colors.orange,
            width: isMob ? double.infinity : 180,
          ),
          _StatCard(
            title: 'Exception',
            value: data.exception.toString(),
            icon: Icons.error,
            color: Colors.red,
            width: isMob ? double.infinity : 180,
          ),
        ],
      ),
    );
  }
}

class _ManagerDashboard extends ConsumerWidget {
  final bool isMob;

  const _ManagerDashboard({required this.isMob});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(warehouseManagerDashboardSummaryProvider);
    final kpis = ref.watch(warehouseManagerAdminKpiProvider);
    final reconciliationOverview = ref.watch(reconciliationDashboardProvider);

    final isInitialLoad = (summary.isLoading && !summary.hasValue) ||
        (kpis.isLoading && !kpis.hasValue) ||
        (reconciliationOverview.isLoading && !reconciliationOverview.hasValue);

    if (isInitialLoad) {
      return ListView(
        padding:
            EdgeInsets.symmetric(horizontal: isMob ? 16 : 24, vertical: 16),
        children: const [
          SkeletonLoader(width: 220, height: 28),
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 120),
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 120),
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 220),
        ],
      );
    }

    final summaryData = summary.valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(warehouseManagerDashboardSummaryProvider.future),
          ref.refresh(warehouseManagerAdminKpiProvider.future),
          ref.refresh(reconciliationDashboardProvider.future),
        ]);
      },
      child: ListView(
      padding: EdgeInsets.symmetric(horizontal: isMob ? 16 : 24, vertical: 16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const GrnImportCard(),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'KPI Overview',
          subtitle:
              'Track gate throughput, GRN health, and exceptions at a glance.',
        ),
        const SizedBox(height: 10),
        if (kpis.hasError)
          _ErrorBanner(message: 'Failed to load KPIs: ${kpis.error}'),
        kpis.when(
          loading: () =>
              const SkeletonLoader(width: double.infinity, height: 140),
          error: (_, __) => const SizedBox.shrink(),
          data: (metrics) => _KpiSection(metrics: metrics, isMob: isMob),
        ),
        const SizedBox(height: 24),
        _ReconciliationOverviewSection(
          data: reconciliationOverview,
          isMob: isMob,
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Approval Overview',
          subtitle: 'Review reconciled entries and finalize the workflow.',
          trailing: TextButton.icon(
            onPressed: () => context.go('/app/reconciliation'),
            icon: const Icon(Icons.rule_folder),
            label: const Text('Open Review Queue'),
          ),
        ),
        const SizedBox(height: 10),
        if (summary.hasError)
          _ErrorBanner(message: 'Failed to load approvals: ${summary.error}'),
        if (summary.isLoading)
          const SkeletonLoader(width: double.infinity, height: 120)
        else if (summaryData != null)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Pending Approval',
                value: summaryData.pendingApproval.toString(),
                icon: Icons.pending_actions,
                color: Colors.orange,
                width: isMob ? double.infinity : 220,
              ),
              _StatCard(
                title: 'Exceptions',
                value: summaryData.exceptions.toString(),
                icon: Icons.error_outline,
                color: Colors.red,
                width: isMob ? double.infinity : 220,
              ),
              _StatCard(
                title: 'Approved Today',
                value: summaryData.approvedToday.toString(),
                icon: Icons.verified,
                color: Colors.blue,
                width: isMob ? double.infinity : 220,
              ),
            ],
          ),
      ],
      ),
    );
  }
}

class _ReconciliationOverviewSection extends StatelessWidget {
  const _ReconciliationOverviewSection({
    required this.data,
    required this.isMob,
  });

  final AsyncValue<ReconciliationDashboardData> data;
  final bool isMob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Reconciliation Overview',
          subtitle: 'Track key mismatch and missing GRN exceptions quickly.',
        ),
        const SizedBox(height: 10),
        data.when(
          loading: () =>
              const SkeletonLoader(width: double.infinity, height: 220),
          error: (e, _) => _ErrorBanner(
            message: 'Failed to load reconciliation overview: $e',
          ),
          data: (overview) {
            final unresolved = overview.records
                .where((record) => !record.isResolved && !record.isMatched)
                .take(5)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReconciliationSummaryCards(
                  summary: overview.summary,
                  isMob: isMob,
                ),
                const SizedBox(height: 14),
                if (unresolved.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child:
                          Text('No unresolved reconciliation records found.'),
                    ),
                  )
                else if (isMob)
                  Column(
                    children: unresolved
                        .map(
                          (record) => _ReconciliationRecordCard(record: record),
                        )
                        .toList(),
                  )
                else
                  _ReconciliationRecordTable(records: unresolved),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go('/app/reconciliation'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View All'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReconciliationSummaryCards extends StatelessWidget {
  const _ReconciliationSummaryCards({
    required this.summary,
    required this.isMob,
  });

  final ReconciliationDashboardSummary summary;
  final bool isMob;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _StatCard(
        title: 'Total Exceptions',
        value: summary.totalExceptions.toString(),
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        width: isMob ? double.infinity : 220,
      ),
      _StatCard(
        title: 'Missing GRN',
        value: summary.missingTotal.toString(),
        icon: Icons.error_outline,
        color: Colors.red,
        width: isMob ? double.infinity : 220,
      ),
      _StatCard(
        title: 'Mismatch',
        value: summary.mismatchTotal.toString(),
        icon: Icons.compare_arrows,
        color: Colors.orange,
        width: isMob ? double.infinity : 220,
      ),
      _StatCard(
        title: 'Field Issues',
        value: summary.totalFieldIssues.toString(),
        icon: Icons.rule,
        color: Colors.indigo,
        width: isMob ? double.infinity : 220,
      ),
    ];

    if (isMob) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => cards[index],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
        const SizedBox(width: 12),
        Expanded(child: cards[2]),
        const SizedBox(width: 12),
        Expanded(child: cards[3]),
      ],
    );
  }
}

class _ReconciliationRecordCard extends StatelessWidget {
  const _ReconciliationRecordCard({required this.record});

  final ReconciliationDashboardRecord record;

  @override
  Widget build(BuildContext context) {
    final status = _statusUi(record);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.gateEntryNo.isNotEmpty
                        ? record.gateEntryNo
                        : record.gateEntryId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                _statusChip(status.label, status.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Issue: ${record.reasonCode.isNotEmpty ? record.reasonCode : '-'}'),
            if (record.reasonDetail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                record.reasonDetail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text('Qty Variance: ${record.qtyVariance}'),
            const SizedBox(height: 2),
            Text(
              'Matched GRN: ${record.matchedGrnNumber.isEmpty ? '-' : record.matchedGrnNumber}',
            ),
            const SizedBox(height: 2),
            Text('Line Issues: ${record.lineIssueCount}'),
            const SizedBox(height: 4),
            Text(
              'Date: ${_formatRecoDate(record.reconciledAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => context.go('/app/reconciliation'),
                child: const Text('View'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconciliationRecordTable extends StatelessWidget {
  const _ReconciliationRecordTable({required this.records});

  final List<ReconciliationDashboardRecord> records;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('Gate Entry No')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Issue')),
              DataColumn(label: Text('Qty Variance')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Action')),
            ],
            rows: records.map((record) {
              final status = _statusUi(record);
              return DataRow(cells: [
                DataCell(Text(record.gateEntryNo.isNotEmpty
                    ? record.gateEntryNo
                    : record.gateEntryId)),
                DataCell(_statusChip(status.label, status.color)),
                DataCell(SizedBox(
                  width: 280,
                  child: Text(
                    record.reasonDetail.isNotEmpty
                        ? '${record.reasonCode.isNotEmpty ? record.reasonCode : '-'} - ${record.reasonDetail}'
                        : (record.reasonCode.isNotEmpty
                            ? record.reasonCode
                            : '-'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text(record.qtyVariance.toString())),
                DataCell(Text(_formatRecoDate(record.reconciledAt))),
                DataCell(
                  OutlinedButton(
                    onPressed: () => context.go('/app/reconciliation'),
                    child: const Text('View'),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StatusUi {
  final String label;
  final Color color;

  const _StatusUi(this.label, this.color);
}

_StatusUi _statusUi(ReconciliationDashboardRecord record) {
  final value = record.statusKey;
  final label = record.displayStatus;

  if (value == 'matched') {
    return _StatusUi(label, Colors.green);
  }
  if (value == 'quantity_mismatch') {
    return _StatusUi(label, Colors.orange);
  }
  if (value == 'grn_not_posted' || value == 'pending_grn') {
    return _StatusUi(label, Colors.red);
  }
  if (value == 'duplicate_grn') {
    return _StatusUi(label, Colors.orange);
  }
  if (value == 'wrong_po_material') {
    return _StatusUi(label, Colors.indigo);
  }

  return _StatusUi(label, Colors.grey);
}

Widget _statusChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

String _formatRecoDate(DateTime? date) {
  if (date == null) return 'N/A';
  return DateFormat('MMM dd, yyyy - hh:mm a').format(date.toLocal());
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.metrics, required this.isMob});

  final DashboardMetrics metrics;
  final bool isMob;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      StatCard(
        title: 'Total Gate Entries (Today/Month)',
        value:
            '${metrics.totalGateEntriesToday} / ${metrics.totalGateEntriesMonth}',
        icon: Icons.local_shipping,
        color: Theme.of(context).colorScheme.primary,
      ),
      StatCard(
        title: 'Gate In',
        value: metrics.gateInCount.toString(),
        icon: Icons.login,
        color: Colors.indigo,
      ),
      StatCard(
        title: 'Gate Out',
        value: metrics.gateOutCount.toString(),
        icon: Icons.logout,
        color: Colors.deepOrange,
      ),
      StatCard(
        title: 'Total GRN Posted',
        value: metrics.totalGrnPosted.toString(),
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      StatCard(
        title: 'Pending GRN Count',
        value: metrics.pendingGrnCount.toString(),
        icon: Icons.pending_actions,
        color: Colors.orange,
      ),
      StatCard(
        title: 'Quantity Mismatch Cases',
        value: metrics.quantityMismatchCases.toString(),
        icon: Icons.warning_amber_rounded,
        color: Colors.redAccent,
      ),
      StatCard(
        title: 'Duplicate GRN Cases',
        value: metrics.duplicateGrnCases.toString(),
        icon: Icons.copy_all,
        color: Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isMob ? 220 : 280,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isMob ? 1.2 : 2.2,
          ),
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => cards[index],
        ),
        const SizedBox(height: 16),
        if (isMob) ...[
          _TatCard(metrics: metrics),
          const SizedBox(height: 14),
          _AgingCard(metrics: metrics),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TatCard(metrics: metrics)),
              const SizedBox(width: 14),
              Expanded(child: _AgingCard(metrics: metrics)),
            ],
          ),
      ],
    );
  }
}

/// Prominent red alert listing vehicles that were gated in but not gated out
/// past the threshold (default 2h). Shown at the top of the security
/// dashboard so security can chase them down -- and record the gate out
/// straight from here once the vehicle has left.
class _OverdueGateOutAlert extends ConsumerStatefulWidget {
  const _OverdueGateOutAlert({required this.metrics});

  final DashboardMetrics metrics;

  @override
  ConsumerState<_OverdueGateOutAlert> createState() =>
      _OverdueGateOutAlertState();
}

class _OverdueGateOutAlertState extends ConsumerState<_OverdueGateOutAlert> {
  static const _errorColor = Color(0xFFD32F2F);
  // Show at most a handful inline; the rest behind "Show all".
  static const _maxVisible = 6;

  bool _showAll = false;
  // Gated out from here -- hidden at once, before the dashboard reloads.
  final Set<String> _gatedOut = {};

  bool get _canGateOut {
    final session = ref.read(sessionControllerProvider);
    if (session is! Authenticated) return false;
    final role = session.role;
    return role == UserRole.gateSecurity ||
        role == UserRole.warehouseExecutive ||
        role.isAdminOrWarehouseManager;
  }

  Future<void> _gateOut(OverdueGateOut v) async {
    final vehicle = v.vehicleNo.isEmpty ? '(no vehicle no)' : v.vehicleNo;
    final remarksController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: _errorColor, size: 32),
        title: Text('Gate Out $vehicle?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v.gateEntryNo.isNotEmpty || v.vendorName.isNotEmpty)
                Text(
                  [
                    if (v.gateEntryNo.isNotEmpty) v.gateEntryNo,
                    if (v.vendorName.isNotEmpty) v.vendorName,
                  ].join(' · '),
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 10),
              Text(
                'Vehicle has been inside for ${v.durationLabel}.',
                style: const TextStyle(
                    color: _errorColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Record the gate out only once the vehicle has actually left '
                'the gate. If it is leaving without unloading, say so in the '
                'remarks.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  hintText: 'e.g. Vehicle exited after unloading',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Confirm Gate Out'),
          ),
        ],
      ),
    );
    final remarks = remarksController.text.trim();
    remarksController.dispose();
    if (proceed != true || !mounted) return;

    final controller = ref.read(gateEntryControllerProvider.notifier);
    final ok = await runWithProgressDialog(
      context,
      () => controller.gateOutEntry(v.id, remarks: remarks),
      label: 'Recording gate out...',
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _gatedOut.add(v.id));
      ref.invalidate(dashboardControllerProvider);
    }
    final error = ref.read(gateEntryControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? Colors.green : Colors.redAccent,
      content: Text(ok
          ? 'Gate out recorded for $vehicle'
          : (error != null && error.isNotEmpty
              ? error
              : 'Gate out failed for $vehicle')),
    ));
  }

  void _openEntry(OverdueGateOut v) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GateEntryDetailPage(entryId: v.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final items = metrics.overdueGateOut
        .where((v) => !_gatedOut.contains(v.id))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final thresholdHours =
        (metrics.overdueGateOutThresholdMinutes / 60).toStringAsFixed(
      metrics.overdueGateOutThresholdMinutes % 60 == 0 ? 0 : 1,
    );
    final visible = _showAll ? items : items.take(_maxVisible).toList();
    final remaining = items.length - visible.length;
    final canGateOut = _canGateOut;
    final narrow = isMobile(context);

    Widget durationChip(OverdueGateOut v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _errorColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Inside ${v.durationLabel}',
            style: const TextStyle(
              color: _errorColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        );

    Widget gateOutButton(OverdueGateOut v) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _errorColor,
            side: BorderSide(color: _errorColor.withValues(alpha: 0.6)),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => _gateOut(v),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Gate Out'),
        );

    Widget row(OverdueGateOut v) {
      final hasId = v.id.isNotEmpty;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: hasId ? () => _openEntry(v) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 18, color: _errorColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.vehicleNo.isEmpty ? '(no vehicle no)' : v.vehicleNo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (v.gateEntryNo.isNotEmpty || v.vendorName.isNotEmpty)
                      Text(
                        [
                          if (v.gateEntryNo.isNotEmpty) v.gateEntryNo,
                          if (v.vendorName.isNotEmpty) v.vendorName,
                        ].join(' · '),
                        maxLines: narrow ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    if (narrow) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          durationChip(v),
                          const Spacer(),
                          if (canGateOut && hasId) gateOutButton(v),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 10),
                durationChip(v),
              ],
              if (!narrow && canGateOut && hasId) ...[
                const SizedBox(width: 10),
                gateOutButton(v),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: _errorColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _errorColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _errorColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${items.length} vehicle${items.length == 1 ? '' : 's'} '
                    'not gated out within ${thresholdHours}h',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _errorColor,
                        ),
                  ),
                ),
              ],
            ),
            if (canGateOut) ...[
              const SizedBox(height: 4),
              Text(
                'Tap Gate Out once a vehicle has left; tap a row to open its '
                'gate entry.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 10),
            ...visible.map(row),
            if (items.length > _maxVisible) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _errorColor),
                onPressed: () => setState(() => _showAll = !_showAll),
                icon: Icon(_showAll
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                label: Text(_showAll
                    ? 'Show less'
                    : 'Show all ${items.length} (+ $remaining more)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TatCard extends StatelessWidget {
  const _TatCard({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final vtatValue = metrics.gateTat > 0
        ? '${metrics.gateTat.toStringAsFixed(0)} mins'
        : 'N/A';
    final didoValue = metrics.dockTat > 0
        ? '${metrics.dockTat.toStringAsFixed(0)} mins'
        : 'N/A';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turnaround Time (TAT)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _infoRow(
              context,
              Icons.timer,
              Colors.blue,
              'VTAT (Gate In → Gate Out)',
              vtatValue,
            ),
            const SizedBox(height: 14),
            _infoRow(
              context,
              Icons.dock,
              Colors.blueGrey,
              'DIDO (Dock In → Dock Out)',
              didoValue,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingCard extends StatelessWidget {
  const _AgingCard({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aging of Pending GRN',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _infoRow(context, Icons.date_range, Colors.green, '0-1 Day',
                '${metrics.pendingGrnAging0To1}'),
            const SizedBox(height: 14),
            _infoRow(context, Icons.date_range, Colors.orange, '2-3 Days',
                '${metrics.pendingGrnAging2To3}'),
            const SizedBox(height: 14),
            _infoRow(context, Icons.date_range, Colors.red, '> 3 Days',
                '${metrics.pendingGrnAgingMoreThan3}'),
          ],
        ),
      ),
    );
  }
}

Widget _infoRow(
  BuildContext context,
  IconData icon,
  Color color,
  String title,
  String value,
) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
