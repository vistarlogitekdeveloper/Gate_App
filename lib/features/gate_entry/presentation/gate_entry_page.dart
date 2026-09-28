import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/filter_bar.dart';
import '../../../core/ui/widgets/logout_action.dart';
import '../../../core/ui/widgets/progress_dialog.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../domain/models/gate_entry.dart';
import '../domain/models/gate_entry_query.dart';
import '../domain/models/gate_entry_summary.dart';
import 'controllers/gate_entry_controller.dart';
import 'gate_entry_detail_page.dart';
import 'gate_entry_form_page.dart';

import '../../warehouse/domain/models/warehouse_gate_entry.dart';
import '../../warehouse/presentation/controllers/warehouse_providers.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/status_chip.dart';

// Shared DateFormat instances — constructing DateFormat per row in
// itemBuilders and inside .where() loops was costing ~10-40µs/row.
final DateFormat _kCompactTimestamp = DateFormat('dd MMM yy • hh:mm a');
final DateFormat _kBulletTimestamp = DateFormat('MMM dd, yyyy • hh:mm a');

class GateEntryPage extends ConsumerWidget {
  const GateEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;
    
    // For exec, show the pending GRN view. Otherwise show the standard operations view.
    if (role == UserRole.warehouseExecutive) {
      return const _WarehouseGateEntryView();
    }
    return const _GateEntrySecurityView();
  }
}

class _GateEntrySecurityView extends ConsumerStatefulWidget {
  const _GateEntrySecurityView();

  @override
  ConsumerState<_GateEntrySecurityView> createState() => _GateEntrySecurityViewState();
}

class _GateEntrySecurityViewState extends ConsumerState<_GateEntrySecurityView> {
  static const List<int> _pageSizeOptions = [20, 50, 100];
  static const String _allFilter = 'All';
  static const String _gateInFilter = 'Gate In';
  static const String _gateOutFilter = 'Gate Out';
  static const String _todayFilter = 'Today';
  static const String _yesterdayFilter = 'Yesterday';
  static const String _thisWeekFilter = 'This Week';
  static const String _thisMonthFilter = 'This Month';

  String _searchQuery = '';
  String _statusFilter = _allFilter;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;

  // Memoized output of _applyFilters. _applyFilters was being called on every
  // parent rebuild (search-debounce ticks, spinner toggles, etc.) and was
  // re-iterating the whole entries list each time. Cache by the identity of
  // the input list + the filter value — both are immutable while in scope.
  List<GateEntry>? _filteredCache;
  List<GateEntry>? _filteredCacheKey;
  String? _filteredCacheFilter;
  DateTime? _filteredCacheDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gateEntryControllerProvider.notifier).fetchEntries(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value != _searchController.text) {
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {
      _searchQuery = value;
      _isSearching = true;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _runServerSearch(value.trim());
    });
  }

  Future<void> _runServerSearch(String text) async {
    final controller = ref.read(gateEntryControllerProvider.notifier);
    final trimmed = text.trim();
    final period =
        _usesServerPeriod(_statusFilter) ? _periodForFilter(_statusFilter) : null;

    try {
      if (trimmed.isEmpty) {
        // Search cleared — restore the normal paginated list for the filter.
        await controller.fetchEntries(
          query: period != null
              ? GateEntryQuery(period: period)
              : const GateEntryQuery(),
          page: 1,
        );
      } else {
        // Vendor isn't covered by the backend's `q` search, so searchEntries
        // fans the term out across `q` + `vendor` and merges the results.
        await controller.searchEntries(trimmed, period: period);
      }
    } finally {
      // Always clear the spinner, even if the request throws unexpectedly.
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Returns true if the entry's gateTimestamp falls on [date]. Uses cheap
  /// integer y/m/d comparison instead of formatting both sides to "yyyy-MM-dd"
  /// strings — at hundreds of rows the formatter alloc dominated frame time.
  bool _isOnDate(GateEntry e, DateTime date, {bool includeExit = false}) {
    final y = date.year;
    final m = date.month;
    final d = date.day;

    final t = e.gateTimestamp?.toLocal();
    if (t != null && t.year == y && t.month == m && t.day == d) {
      return true;
    }

    if (includeExit && e.gateOutTimestamp != null) {
      final o = e.gateOutTimestamp!.toLocal();
      if (o.year == y && o.month == m && o.day == d) return true;
    }

    return false;
  }

  List<GateEntry> _applyFilters(List<GateEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Return cached result if inputs are unchanged. `identical(entries, key)`
    // is cheap and the controller hands the same list instance back until
    // it refetches, so most rebuilds (text-field input, spinner toggles)
    // skip the filter pass entirely.
    if (identical(entries, _filteredCacheKey) &&
        _statusFilter == _filteredCacheFilter &&
        _filteredCacheDay == today &&
        _filteredCache != null) {
      return _filteredCache!;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final tomorrow = today.add(const Duration(days: 1));
    final nextMonth =
        today.month == 12 ? DateTime(today.year + 1, 1, 1) : DateTime(today.year, today.month + 1, 1);

    final result = entries.where((e) {
      switch (_statusFilter) {
        case _gateInFilter:
          // Only show those that are "In" and HAVEN'T gone out yet
          return e.gateMovement == GateMovement.inMovement && e.gateOutTimestamp == null;
        case _gateOutFilter:
          // Show those that are "Out" entries OR "In" entries that HAVE gone out
          return e.gateMovement == GateMovement.outMovement || e.gateOutTimestamp != null;
        case _todayFilter:
          return _isOnDate(e, today);
        case _yesterdayFilter:
          return _isOnDate(e, yesterday);
        case _thisWeekFilter:
          final t = e.gateTimestamp?.toLocal();
          return t != null && !t.isBefore(weekStart) && t.isBefore(tomorrow);
        case _thisMonthFilter:
          final t = e.gateTimestamp?.toLocal();
          return t != null && !t.isBefore(monthStart) && t.isBefore(nextMonth);
        default:
          return true;
      }
    }).toList();

    _filteredCache = result;
    _filteredCacheKey = entries;
    _filteredCacheFilter = _statusFilter;
    _filteredCacheDay = today;
    return result;
  }

  bool _usesServerPeriod(String filter) {
    return filter == _todayFilter ||
        filter == _yesterdayFilter ||
        filter == _thisWeekFilter ||
        filter == _thisMonthFilter;
  }

  String? _periodForFilter(String filter) {
    switch (filter) {
      case _todayFilter:
        return 'today';
      case _yesterdayFilter:
        return 'yesterday';
      case _thisWeekFilter:
        return 'this_week';
      case _thisMonthFilter:
        return 'this_month';
      default:
        return null;
    }
  }

  Future<void> _selectFilter(String filter) async {
    if (!mounted) return;
    setState(() => _statusFilter = filter);

    final controller = ref.read(gateEntryControllerProvider.notifier);
    final gateEntryState = ref.read(gateEntryControllerProvider);
    final trimmedSearch = _searchQuery.trim();
    final searchValue = trimmedSearch.isEmpty ? null : trimmedSearch;
    final period =
        _usesServerPeriod(filter) ? _periodForFilter(filter) : null;

    // With an active search term, fan out across `q` + `vendor` (searchEntries)
    // so vendor matches aren't dropped when a chip is toggled.
    if (searchValue != null) {
      await controller.searchEntries(searchValue, period: period);
      return;
    }

    if (period != null) {
      await controller.fetchEntries(
        query: GateEntryQuery(period: period),
        page: 1,
        usePagination: gateEntryState.pagination != null,
      );
      return;
    }

    // For "All"/"Gate In"/"Gate Out" — server returns paginated full list,
    // status chip is applied client-side.
    await controller.fetchEntries(
      query: const GateEntryQuery(),
      page: 1,
      usePagination: gateEntryState.pagination != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gateEntryControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;
    // Admin is included so a backdated entry can actually be raised: the
    // create route already authorises gate_security, warehouse_executive and
    // admin server-side, but the button was gate-security only, which left
    // admins with no way to reach the form at all.
    final canCreate =
        role == UserRole.gateSecurity || role == UserRole.admin;
    final isMob = isMobile(context);
    final isTab = isTablet(context);
    final filtered = _applyFilters(state.entries);
    const bottomActionClearance = 24.0;

    void openCreateForm() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GateEntryFormPage(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Entry Management'),
        actions: [
          if (canCreate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: isMob
                  ? IconButton(
                      tooltip: 'Create Gate Entry',
                      icon: const Icon(Icons.add),
                      onPressed: openCreateForm,
                    )
                  : FilledButton.icon(
                      onPressed: openCreateForm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Gate Entry'),
                    ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(gateEntryControllerProvider.notifier)
                .fetchEntries(refresh: true),
          ),
          const LogoutAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading && state.entries.isEmpty
          ? _buildLoadingView(isMob, isTab)
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => ref
                      .read(gateEntryControllerProvider.notifier)
                      .fetchEntries(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = constraints.maxWidth > 1440
                          ? 1440.0
                          : constraints.maxWidth;

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              isMob ? 16 : 24,
                              isMob ? 16 : 24,
                              isMob ? 16 : 24,
                              bottomActionClearance,
                            ),
                            children: [
                              _buildSummarySection(
                                context,
                                state.summary,
                                isMob,
                                isTab,
                              ),
                              const SizedBox(height: 16),
                              _buildFilters(context, filtered.length, isMob),
                              if (state.error != null) ...[
                                const SizedBox(height: 12),
                                _buildErrorBanner(context, state.error!),
                              ],
                              const SizedBox(height: 16),
                              filtered.isEmpty
                                  ? _buildEmptyState(context)
                                  : isMob
                                      ? _buildMobileList(filtered)
                                      : _buildDesktopTable(filtered, isTab),
                              const SizedBox(height: 16),
                              _buildPaginationSection(
                                context,
                                state,
                                filtered.length,
                                isMob,
                              ),
                              SizedBox(height: canCreate ? 16 : 0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (state.isLoading && state.entries.isNotEmpty)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLoadingView(bool isMob, bool isTab) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isMob ? 16 : 24,
        vertical: isMob ? 16 : 24,
      ),
      children: [
        if (isMob)
          const SkeletonLoader(width: double.infinity, height: 84)
        else
          Row(
            children: [
              Expanded(
                child: SkeletonLoader(
                  width: double.infinity,
                  height: isTab ? 76 : 84,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  width: double.infinity,
                  height: isTab ? 76 : 84,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  width: double.infinity,
                  height: isTab ? 76 : 84,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  width: double.infinity,
                  height: isTab ? 76 : 84,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const SkeletonLoader(width: double.infinity, height: 88),
        const SizedBox(height: 16),
        const SkeletonLoader(width: double.infinity, height: 420),
      ],
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    GateEntrySummary summary,
    bool isMob,
    bool isTab,
  ) {
    final cards = [
      _summaryCard(
        context,
        title: _gateInFilter,
        value: '${summary.gateIn}',
        subtitle: 'Incoming vehicles',
        icon: Icons.login,
        accent: Colors.indigo,
        isSelected: _statusFilter == _gateInFilter,
        onTap: () => _selectFilter(_gateInFilter),
      ),
      _summaryCard(
        context,
        title: _gateOutFilter,
        value: '${summary.gateOut}',
        subtitle: 'Outgoing vehicles',
        icon: Icons.logout,
        accent: Colors.deepOrange,
        isSelected: _statusFilter == _gateOutFilter,
        onTap: () => _selectFilter(_gateOutFilter),
      ),
      _summaryCard(
        context,
        title: 'Total',
        value: '${summary.total}',
        subtitle: 'All gate entries',
        icon: Icons.dashboard_customize,
        accent: Colors.blueGrey,
        isSelected: _statusFilter == _allFilter,
        onTap: () => _selectFilter(_allFilter),
      ),
      _summaryCard(
        context,
        title: _todayFilter,
        value: '${summary.today}',
        subtitle: 'Entries today',
        icon: Icons.today,
        accent: Colors.teal,
        isSelected: _statusFilter == _todayFilter,
        onTap: () => _selectFilter(_todayFilter),
      ),
      _summaryCard(
        context,
        title: _yesterdayFilter,
        value: '${summary.yesterday}',
        subtitle: 'Entries yesterday',
        icon: Icons.history,
        accent: Colors.purple,
        isSelected: _statusFilter == _yesterdayFilter,
        onTap: () => _selectFilter(_yesterdayFilter),
      ),
      _summaryCard(
        context,
        title: _thisWeekFilter,
        value: '${summary.thisWeek}',
        subtitle: 'Entries this week',
        icon: Icons.view_week,
        accent: Colors.cyan,
        isSelected: _statusFilter == _thisWeekFilter,
        onTap: () => _selectFilter(_thisWeekFilter),
      ),
      _summaryCard(
        context,
        title: _thisMonthFilter,
        value: '${summary.thisMonth}',
        subtitle: 'Entries this month',
        icon: Icons.calendar_month,
        accent: Colors.amber.shade800,
        isSelected: _statusFilter == _thisMonthFilter,
        onTap: () => _selectFilter(_thisMonthFilter),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isMob ? 8.0 : 10.0;
        final columns = isMob ? 2 : (isTab ? 4 : 5);
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isSelected
        ? accent.withValues(alpha: 0.7)
        : colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.08)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isSelected ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
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

  Widget _buildFilters(BuildContext context, int count, bool isMob) {
    final pagination = ref.watch(gateEntryControllerProvider).pagination;
    final total = pagination?.total ?? count;

    return FilterBar(
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count of $total records',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
      children: [
        SizedBox(
          width: isMob ? double.infinity : 320,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search challan, LR, vendor, vehicle',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () => _onSearchChanged(''),
                        )
                      : null),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
        ),
        SizedBox(
          width: isMob ? double.infinity : 220,
          child: DropdownButtonFormField<String>(
            key: ValueKey(_statusFilter),
            initialValue: _statusFilter,
            decoration: InputDecoration(
              labelText: 'Filter',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: _allFilter, child: Text('All')),
              DropdownMenuItem(value: _gateInFilter, child: Text('Gate In')),
              DropdownMenuItem(value: _gateOutFilter, child: Text('Gate Out')),
              DropdownMenuItem(value: _todayFilter, child: Text('Today')),
              DropdownMenuItem(value: _yesterdayFilter, child: Text('Yesterday')),
              DropdownMenuItem(value: _thisWeekFilter, child: Text('This Week')),
              DropdownMenuItem(value: _thisMonthFilter, child: Text('This Month')),
            ],
            onChanged: (val) {
              if (val != null) {
                _selectFilter(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _vendorLabel(GateEntry entry) {
    return entry.vendorCode.isEmpty
        ? entry.vendorName
        : '${entry.vendorName} (${entry.vendorCode})';
  }

  String _transporterLabel(GateEntry entry) {
    return entry.transporterName;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'N/A';
    return _kCompactTimestamp.format(timestamp.toLocal());
  }

  // ─── Mobile List ──────────────────────────────────────────────────────────

  Widget _buildMobileList(List<GateEntry> entries) {
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _MobileEntryCard(
          entry: entry,
          role: role,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GateEntryDetailPage(entryId: entry.id),
            ),
          ),
          onVerify: () => _confirmAndAct(
            context,
            title: 'Verify Entry',
            message: 'Verify this gate entry?',
            action: () => ref
                .read(gateEntryControllerProvider.notifier)
                .verifyEntry(entry.id),
          ),
          onApprove: () => _confirmAndAct(
            context,
            title: 'Approve Entry',
            message: 'Approve this gate entry?',
            action: () => ref
                .read(gateEntryControllerProvider.notifier)
                .approveEntry(entry.id),
          ),
          onClose: () => _confirmAndAct(
            context,
            title: 'Close Entry',
            message: 'Close this gate entry?',
            action: () => ref
                .read(gateEntryControllerProvider.notifier)
                .closeEntry(entry.id),
          ),
          formatTimestamp: _formatTimestamp,
          vendorLabel: _vendorLabel,
        );
      },
    );
  }

  // ─── Desktop Table ────────────────────────────────────────────────────────

  Widget _buildDesktopTable(List<GateEntry> entries, bool isTab) {
    return SizedBox(
      height: 560,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DataTable2(
            columnSpacing: isTab ? 10 : 14,
            horizontalMargin: isTab ? 16 : 24,
            minWidth: 1280,
            headingRowHeight: 60,
            dataRowHeight: 68,
            showCheckboxColumn: false,
            columns: const [
              DataColumn2(label: Text('Direction'), size: ColumnSize.S),
              DataColumn2(label: Text('Challan No'), size: ColumnSize.M),
              DataColumn2(label: Text('LR Number'), size: ColumnSize.M),
              DataColumn2(label: Text('Material'), size: ColumnSize.S),
              DataColumn2(
                  label: Text('Qty'), size: ColumnSize.S, numeric: true),
              DataColumn2(label: Text('Vendor'), size: ColumnSize.L),
              DataColumn2(label: Text('Transporter'), size: ColumnSize.L),
              DataColumn2(label: Text('Vehicle No'), size: ColumnSize.M),
              DataColumn2(label: Text('Entry Time'), size: ColumnSize.M),
            ],
            rows: entries.map((entry) {
              final isExited = entry.gateOutTimestamp != null;
              final isGateIn = entry.gateMovement == GateMovement.inMovement;
              
              // If it has exited, we show "Gate Out" icon/text regardless of movement type
              final effectiveDirectionIcon = (isExited || !isGateIn) ? Icons.logout : Icons.login;
              final effectiveDirectionColor = (isExited || !isGateIn) ? Colors.deepOrange : Colors.indigo;
              final effectiveDirectionLabel = (isExited || !isGateIn) ? 'Gate Out' : 'Gate In';
              final firstMaterial = entry.items.isNotEmpty
                  ? entry.items.first.materialCode.trim()
                  : '';
              final materialCode = firstMaterial.isEmpty ? '-' : firstMaterial;
              final qty = entry.items.isNotEmpty
                  ? entry.items.fold(0, (sum, i) => sum + i.challanQty)
                  : 0;

              return DataRow(
                onSelectChanged: (_) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GateEntryDetailPage(entryId: entry.id),
                    ),
                  );
                },
                cells: [
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          effectiveDirectionIcon,
                          size: 18,
                          color: effectiveDirectionColor,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            effectiveDirectionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      entry.challanNo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(entry.lrNumber.isEmpty ? '-' : entry.lrNumber)),
                  DataCell(Text(materialCode)),
                  DataCell(
                    Text(
                      qty.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(_vendorLabel(entry))),
                  DataCell(Text(_transporterLabel(entry))),
                  DataCell(
                    Text(entry.vehicleNo.isEmpty ? '-' : entry.vehicleNo),
                  ),
                  DataCell(Text(_formatTimestamp(entry.gateTimestamp))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No gate entries found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing the search text or filter to see more records.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationSection(
    BuildContext context,
    GateEntryState state,
    int visibleCount,
    bool isMob,
  ) {
    final pagination = state.pagination;
    final controller = ref.read(gateEntryControllerProvider.notifier);
    final total = pagination?.total ??
        (state.summary.total > 0 ? state.summary.total : state.entries.length);
    final from = pagination == null
        ? (visibleCount == 0 ? 0 : 1)
        : (pagination.total == 0 ? 0 : ((pagination.page - 1) * pagination.limit) + 1);
    final to = pagination == null
        ? visibleCount
        : (pagination.total == 0
            ? 0
            : (((pagination.page - 1) * pagination.limit) + visibleCount)
                .clamp(0, pagination.total));

    // A search fans out across every page of two filters (see
    // GateEntryController.searchEntries) and drops server pagination, so
    // during search we know we're already showing everything that matched.
    final isSearchMode = pagination == null && _searchQuery.trim().isNotEmpty;
    final statusText = isSearchMode
        ? 'Showing all $visibleCount ${visibleCount == 1 ? 'result' : 'results'}'
        : pagination == null
            ? 'Showing all $visibleCount of $total'
            : (visibleCount == pagination.limit || visibleCount == 0
                ? 'Showing $from-$to of ${pagination.total}'
                : 'Showing $visibleCount filtered items on page ${pagination.page} of ${pagination.totalPages}');

    final pageSizeValue = _pageSizeOptions.contains(pagination?.limit)
        ? pagination!.limit
        : _pageSizeOptions.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: isMob
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: pageSizeValue,
                        decoration: InputDecoration(
                          labelText: 'Per page',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _pageSizeOptions
                            .map(
                              (size) => DropdownMenuItem<int>(
                                value: size,
                                child: Text('$size'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          controller.fetchEntries(
                            page: 1,
                            limit: value,
                            usePagination: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pagination != null && pagination.hasPrev
                            ? () => controller.fetchEntries(page: pagination.page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: pagination != null && pagination.hasNext
                            ? () => controller.fetchEntries(page: pagination.page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: pageSizeValue,
                    decoration: InputDecoration(
                      labelText: 'Per page',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _pageSizeOptions
                        .map(
                          (size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      controller.fetchEntries(
                        page: 1,
                        limit: value,
                        usePagination: true,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: pagination != null && pagination.hasPrev
                      ? () => controller.fetchEntries(page: pagination.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: pagination != null && pagination.hasNext
                      ? () => controller.fetchEntries(page: pagination.page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
    );
  }



  Future<void> _confirmAndAct(
    BuildContext context, {
    required String title,
    required String message,
    required Future<bool> Function() action,
  }) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    if (!context.mounted) return;

    final success = await runWithProgressDialog(
      context,
      action,
      label: '$title...',
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action completed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      ref
          .read(gateEntryControllerProvider.notifier)
          .fetchEntries(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action failed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ─── Compact Mobile Card ───────────────────────────────────────────────────

class _MobileEntryCard extends StatelessWidget {
  const _MobileEntryCard({
    required this.entry,
    required this.role,
    required this.onTap,
    required this.onVerify,
    required this.onApprove,
    required this.onClose,
    required this.formatTimestamp,
    required this.vendorLabel,
  });

  final GateEntry entry;
  final UserRole? role;
  final VoidCallback onTap;
  final VoidCallback onVerify;
  final VoidCallback onApprove;
  final VoidCallback onClose;
  final String Function(DateTime?) formatTimestamp;
  final String Function(GateEntry) vendorLabel;

  bool get _isExited => entry.gateOutTimestamp != null;
  bool get _isGateIn => entry.gateMovement == GateMovement.inMovement;
  
  Color get _directionColor => (_isExited || !_isGateIn) ? Colors.deepOrange : Colors.indigo;
  IconData get _directionIcon => (_isExited || !_isGateIn) ? Icons.logout : Icons.login;
  String get _directionLabel => (_isExited || !_isGateIn) ? 'Gate Out' : 'Gate In';

  Color get _statusColor {
    switch (entry.status) {
      case 'inward_created':
        return Colors.orange;
      case 'verification_pending':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  String get _statusLabel {
    switch (entry.status) {
      case 'inward_created':
        return 'Pending';
      case 'verification_pending':
        return 'In Review';
      case 'approved':
        return 'Approved';
      case 'closed':
        return 'Closed';
      default:
        return entry.status;
    }
  }

  bool get _showVerify =>
      entry.status == 'inward_created' &&
      (role == UserRole.warehouseExecutive || role.isAdminOrWarehouseManager);
  bool get _showApprove =>
      entry.status == 'verification_pending' &&
      (role == UserRole.warehouseManager ||
          role == UserRole.admin ||
          role == UserRole.whMgr);
  bool get _showClose =>
      entry.status == 'approved' &&
      (role == UserRole.warehouseManager ||
          role == UserRole.admin ||
          role == UserRole.whMgr);
  bool get _showActions => _showVerify || _showApprove || _showClose;

  @override
  Widget build(BuildContext context) {
    final qty = entry.items.isNotEmpty
        ? entry.items.fold(0, (sum, i) => sum + i.challanQty)
        : 0;
    final firstMaterial = entry.items.isNotEmpty
        ? entry.items.first.materialCode.trim()
        : '';
    final materialCode = firstMaterial.isEmpty ? 'N/A' : firstMaterial;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _directionColor.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: direction icon + challan + status chip ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _directionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_directionIcon, color: _directionColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.challanNo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _directionLabel,
                        style: TextStyle(
                          color: _directionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Info row 1: Vendor + LR ──
            Row(
              children: [
                Expanded(
                  child: _infoCell(
                    context,
                    icon: Icons.store_outlined,
                    label: 'Vendor',
                    value: vendorLabel(entry),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoCell(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'LR No',
                    value: entry.lrNumber.isEmpty ? 'N/A' : entry.lrNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Info row 2: Vehicle + Qty ──
            Row(
              children: [
                Expanded(
                  child: _infoCell(
                    context,
                    icon: Icons.local_shipping_outlined,
                    label: 'Vehicle',
                    value: entry.vehicleNo.isEmpty ? 'N/A' : entry.vehicleNo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoCell(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Qty / Material',
                    value: '$qty  •  $materialCode',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Bottom row: time + optional driver ──
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatTimestamp(entry.gateTimestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.driverContactNo.isNotEmpty) ...[
                  Icon(
                    Icons.phone_outlined,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.driverContactNo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            // ── Action buttons ──
            if (_showActions) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_showVerify)
                    _actionBtn(
                      context,
                      label: 'Verify',
                      color: Colors.blue,
                      onPressed: onVerify,
                    ),
                  if (_showApprove)
                    _actionBtn(
                      context,
                      label: 'Approve',
                      color: Colors.green,
                      onPressed: onApprove,
                    ),
                  if (_showClose)
                    _actionBtn(
                      context,
                      label: 'Close',
                      color: Colors.grey,
                      onPressed: onClose,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCell(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// WAREHOUSE ENTRY VIEW (merged from warehouse_gate_entry_list_page.dart)
// ---------------------------------------------------------------------------

class _WarehouseGateEntryView extends ConsumerWidget {
  const _WarehouseGateEntryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(warehouseGateEntriesProvider);
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;
    final isManager =
        role == UserRole.warehouseManager || role == UserRole.whMgr;
    final isMob = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isManager ? 'Gate Entries' : 'Pending GRNs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(warehouseGateEntriesProvider.future),
          ),
          const LogoutAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: entries.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SkeletonLoader(width: 260, height: 32),
            SizedBox(height: 16),
            SkeletonLoader(width: double.infinity, height: 120),
            SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 120),
          ],
        ),
        error: (e, _) => Center(child: Text('Failed to load entries: $e')),
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child:
                  Text(isManager ? 'No gate entries found' : 'No pending GRNs'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(warehouseGateEntriesProvider.future),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMob ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: isManager
                        ? 'Warehouse Gate Entries'
                        : 'Gate Entries Pending GRN',
                    subtitle: isManager
                        ? 'Tap an entry to inspect details and approve or close it.'
                        : 'Tap an entry to inspect details and create GRN.',
                    trailing: isMob
                        ? null
                        : Text(
                            'Total: ${data.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isMob
                        ? _buildMobileList(data)
                        : _buildDesktopTable(context, data),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileList(List<WarehouseGateEntrySummary> entries) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GateEntryDetailPage(entryId: entry.id),
              ),
            );
          },
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.gateEntryNo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: entry.statusLabel,
                        color: _statusColor(entry.statusLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Vendor: ${entry.vendorName}'),
                  const SizedBox(height: 6),
                  Text('Vehicle: ${entry.vehicleNo}'),
                  const SizedBox(height: 6),
                  Text(
                    'PO: ${entry.poNumber.isEmpty ? 'N/A' : entry.poNumber}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Date: ${entry.entryTime != null ? _kBulletTimestamp.format(entry.entryTime!) : 'N/A'}',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<WarehouseGateEntrySummary> entries,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
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
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 24,
          minWidth: 800,
          columns: const [
            DataColumn2(label: Text('Gate Entry No'), size: ColumnSize.M),
            DataColumn2(label: Text('Vendor'), size: ColumnSize.L),
            DataColumn2(label: Text('Vehicle'), size: ColumnSize.M),
            DataColumn2(label: Text('Date'), size: ColumnSize.M),
            DataColumn2(label: Text('Status'), size: ColumnSize.S),
          ],
          rows: entries.map((entry) {
            return DataRow(
              onSelectChanged: (_) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GateEntryDetailPage(entryId: entry.id),
                  ),
                );
              },
              cells: [
                DataCell(Text(entry.gateEntryNo)),
                DataCell(Text(entry.vendorName)),
                DataCell(Text(entry.vehicleNo)),
                DataCell(Text(
                  entry.entryTime != null
                      ? _kBulletTimestamp.format(entry.entryTime!)
                      : 'N/A',
                )),
                DataCell(
                  StatusChip(
                    label: entry.statusLabel,
                    color: _statusColor(entry.statusLabel),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('closed')) return Colors.grey;
    if (normalized.contains('approved')) return Colors.green;
    if (normalized.contains('verified')) return Colors.blue;
    return Colors.orange;
  }
}
