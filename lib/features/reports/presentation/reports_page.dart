import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/pagination_model.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/status_chip.dart';
import '../../../core/ui/widgets/logout_action.dart';
import '../../gate_entry/domain/models/gate_entry_summary.dart';
import '../data/reports_repository_impl.dart';
import '../domain/models/report_models.dart';
import '../domain/models/exception_report_item.dart';
import '../domain/services/report_export_service.dart';

// Shared once-allocated DateFormat instances. Constructing DateFormat is
// expensive (pattern parse + intl symbol alloc) — doing it once per row
// in itemBuilders was the biggest jank source on this screen.
final DateFormat _kListDateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
final DateFormat _kShortDateFormat = DateFormat('MMM dd');
final DateFormat _kDayDateFormat = DateFormat('MMM dd, yyyy');
final NumberFormat _kRowCountFormat = NumberFormat.decimalPattern();

class _ReportQuery {
  final String reportType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? search;
  final String? gateEntryPeriod;
  final int? gateEntryPage;
  final int? gateEntryLimit;

  const _ReportQuery({
    required this.reportType,
    required this.startDate,
    required this.endDate,
    required this.search,
    required this.gateEntryPeriod,
    required this.gateEntryPage,
    required this.gateEntryLimit,
  });

  @override
  bool operator ==(Object other) {
    return other is _ReportQuery &&
        reportType == other.reportType &&
        _dtKey(startDate) == _dtKey(other.startDate) &&
        _dtKey(endDate) == _dtKey(other.endDate) &&
        search == other.search &&
        gateEntryPeriod == other.gateEntryPeriod &&
        gateEntryPage == other.gateEntryPage &&
        gateEntryLimit == other.gateEntryLimit;
  }

  @override
  int get hashCode => Object.hash(
        reportType,
        _dtKey(startDate),
        _dtKey(endDate),
        search,
        gateEntryPeriod,
        gateEntryPage,
        gateEntryLimit,
      );

  String? _dtKey(DateTime? value) => value?.toIso8601String();
}

class _ReportPreviewData {
  final List<GateEntryReportItem> gateEntries;
  final GateEntrySummary gateEntrySummary;
  final PaginationModel? gateEntryPagination;
  final List<GrnReconReportItem> grnRecons;
  final List<ExceptionReportItem> exceptions;

  const _ReportPreviewData({
    this.gateEntries = const [],
    this.gateEntrySummary = const GateEntrySummary(),
    this.gateEntryPagination,
    this.grnRecons = const [],
    this.exceptions = const [],
  });
}

bool _matchesSearchText(String? search, List<String?> values) {
  final query = search?.trim().toLowerCase() ?? '';
  if (query.isEmpty) return true;
  for (final value in values) {
    final text = value?.toLowerCase() ?? '';
    if (text.contains(query)) return true;
  }
  return false;
}

final reportsPreviewProvider =
    FutureProvider.autoDispose.family<_ReportPreviewData, _ReportQuery>(
  (ref, query) async {
    final repo = ref.read(reportsRepositoryProvider);
    final filter = ReportFilter(
      startDate: query.startDate,
      endDate: query.endDate?.add(const Duration(days: 1)),
      vendorFilter: null,
      poFilter: null,
    );
    final search = query.search;

    if (query.reportType == 'Gate Entry Register' ||
        query.reportType == 'Vehicle TAT Report') {
      final data = await repo.getGateEntryRegisterPage(
        filter,
        q: search,
        period: query.gateEntryPeriod,
        page: query.gateEntryPage,
        limit: query.gateEntryLimit,
      );
      return _ReportPreviewData(
        gateEntries: data.items,
        gateEntrySummary: data.summary,
        gateEntryPagination: data.pagination,
      );
    }
    if (query.reportType == 'GRN Reconciliation Report') {
      final data = await repo.getGrnReconReport(filter);
      final filtered = data.where((item) {
        return _matchesSearchText(search, [
          item.gateEntryNo,
          item.challanNo,
          item.vendorName,
          item.vendor,
          item.poNumber,
          item.purchaseOrder,
          item.grnNo,
          item.materialDocument,
          item.referenceNo,
          item.status,
          item.matchedStatus,
        ]);
      }).toList();
      return _ReportPreviewData(grnRecons: filtered);
    }
    final data = await repo.getExceptionReport(filter);
    final filtered = data.where((item) {
      return _matchesSearchText(search, [
        item.gateEntryNo,
        item.invoiceNo,
        item.partNo,
        item.vendorName,
        item.vendorCode,
        item.poNumber,
        item.status,
        item.description,
      ]);
    }).toList();
    return _ReportPreviewData(exceptions: filtered);
  },
);

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  static const List<int> _pageSizeOptions = [20, 50, 100];
  static const String _reportAllFilter = 'All';
  static const String _gateInFilter = 'Gate In';
  static const String _gateOutFilter = 'Gate Out';
  static const String _todayFilter = 'Today';
  static const String _yesterdayFilter = 'Yesterday';
  static const String _thisWeekFilter = 'This Week';
  static const String _thisMonthFilter = 'This Month';

  final _exportService = ReportExportService();
  String _selectedReport = 'Gate Entry Register';
  String _gateEntryCardFilter = _reportAllFilter;
  // Default to a bounded page load. Previously both fields were `null`, which
  // omitted the `limit` query param entirely and made the server return every
  // gate entry in the tenant (2.1 MB / 9 s / thousands of render exceptions
  // observed on 2026-09-15). Pagination controls further down the page let
  // the user grow this to 50 or 100 rows.
  int? _gateEntryPage = 1;
  int? _gateEntryLimit = 20;
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;

  /// Percent label shown on the export button while a large file is being
  /// generated; null when idle. Without this the button sat on a bare
  /// "Generating..." with no way to tell progress from a hang.
  String? _exportProgress;

  /// Rows rendered at once in the GRN and Exception preview tables.
  /// DataTable is not virtualised, so the whole page is built eagerly.
  static const int _clientPageSize = 50;
  int _grnPage = 0;
  int _exceptionPage = 0;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();
  // Debounced search keeps each keystroke from refetching the API.
  String _searchQuery = '';
  Timer? _searchDebounce;

  final List<String> _reportTypes = [
    'Gate Entry Register',
    'GRN Reconciliation Report',
    'Exception Report',
    'Vehicle TAT Report',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed == _searchQuery) return;
      setState(() {
        _searchQuery = trimmed;
        _resetGateEntryPaging();
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _resetGateEntryPaging();
    });
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _resetGateEntryPaging() {
    _gateEntryPage = _gateEntryLimit == null ? null : 1;
  }

  bool _isGateEntryOnDate(
    GateEntryReportItem item,
    DateTime date, {
    bool includeExit = false,
  }) {
    final target = _dateOnly(date);
    if (_dateOnly(item.date.toLocal()) == target) {
      return true;
    }
    if (includeExit && item.gateOutDate != null) {
      return _dateOnly(item.gateOutDate!.toLocal()) == target;
    }
    return false;
  }

  bool _isGateEntryGateOut(GateEntryReportItem item) {
    return item.gateOutDate != null ||
        item.direction.toLowerCase().contains('out');
  }

  bool _isGateEntryGateIn(GateEntryReportItem item) {
    return !_isGateEntryGateOut(item);
  }

  List<GateEntryReportItem> _applyGateEntryCardFilter(
    List<GateEntryReportItem> items,
  ) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final tomorrow = today.add(const Duration(days: 1));
    final nextMonth = today.month == 12
        ? DateTime(today.year + 1, 1, 1)
        : DateTime(today.year, today.month + 1, 1);

    return items.where((item) {
      switch (_gateEntryCardFilter) {
        case _gateInFilter:
          return _isGateEntryGateIn(item);
        case _gateOutFilter:
          return _isGateEntryGateOut(item);
        case _todayFilter:
          return _isGateEntryOnDate(item, today, includeExit: true);
        case _yesterdayFilter:
          return _isGateEntryOnDate(item, yesterday, includeExit: true);
        case _thisWeekFilter:
          final ts = item.date.toLocal();
          return !ts.isBefore(weekStart) && ts.isBefore(tomorrow);
        case _thisMonthFilter:
          final ts = item.date.toLocal();
          return !ts.isBefore(monthStart) && ts.isBefore(nextMonth);
        default:
          return true;
      }
    }).toList();
  }

  _ReportPreviewData _previewWithCardFilter(_ReportPreviewData data) {
    if (_selectedReport == 'Gate Entry Register' ||
        _selectedReport == 'Vehicle TAT Report') {
      return _ReportPreviewData(
        gateEntries: _applyGateEntryLocalFilter(data.gateEntries),
        gateEntrySummary: data.gateEntrySummary,
        gateEntryPagination: data.gateEntryPagination,
      );
    }

    // Exception & GRN reports are fetched search-agnostic (search is kept out
    // of the provider key) and filtered here in-memory, so refining the search
    // never triggers a refetch.
    final search = _searchQuery;
    if (search.isEmpty) return data;

    if (_selectedReport == 'GRN Reconciliation Report') {
      return _ReportPreviewData(
        grnRecons: data.grnRecons
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.challanNo,
                  item.vendorName,
                  item.vendor,
                  item.poNumber,
                  item.purchaseOrder,
                  item.grnNo,
                  item.materialDocument,
                  item.referenceNo,
                  item.status,
                  item.matchedStatus,
                ]))
            .toList(),
      );
    }

    if (_selectedReport == 'Exception Report') {
      return _ReportPreviewData(
        exceptions: data.exceptions
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.invoiceNo,
                  item.partNo,
                  item.vendorName,
                  item.vendorCode,
                  item.poNumber,
                  item.status,
                  item.description,
                ]))
            .toList(),
      );
    }

    return data;
  }

  bool _usesServerPeriod() {
    final tatOrRegister = _selectedReport == 'Gate Entry Register' ||
        _selectedReport == 'Vehicle TAT Report';
    return tatOrRegister &&
        _startDate == null &&
        _endDate == null &&
        (_gateEntryCardFilter == _todayFilter ||
            _gateEntryCardFilter == _yesterdayFilter ||
            _gateEntryCardFilter == _thisWeekFilter ||
            _gateEntryCardFilter == _thisMonthFilter);
  }

  String? _periodForGateEntryFilter() {
    switch (_gateEntryCardFilter) {
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

  List<GateEntryReportItem> _applyGateEntryLocalFilter(
    List<GateEntryReportItem> items,
  ) {
    if (_usesServerPeriod()) {
      return items;
    }
    return _applyGateEntryCardFilter(items);
  }

  ReportFilter _buildExportFilter() {
    return ReportFilter(
      startDate: _startDate,
      endDate: _endDate?.add(const Duration(days: 1)),
      vendorFilter: null,
      poFilter: null,
    );
  }

  String _exportSuccessMessage(String kind) {
    if (kIsWeb) return '$kind downloaded.';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return '$kind ready — pick "Save to Files" in the share sheet.';
    }
    return '$kind saved to Downloads folder. Check your File Manager.';
  }

  /// Fed to the Excel writer, which reports every couple of thousand rows.
  void _handleExportProgress(int written, int total) {
    if (!mounted || total <= 0) return;
    final next = '${((written / total) * 100).clamp(0, 100).round()}%';
    if (next == _exportProgress) return;
    setState(() => _exportProgress = next);
  }

  /// PDF renders every row as vector text, so a full register is both
  /// enormous and slow enough to look hung. Ask before truncating — quietly
  /// dropping rows from a report someone is about to file would be worse than
  /// refusing. Returns null when the user cancels.
  Future<List<T>?> _confirmPdfRowLimit<T>(List<T> data) async {
    const limit = ReportExportService.pdfRowLimit;
    if (data.length <= limit) return data;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Too many rows for PDF'),
        content: Text(
          'This report has ${_kRowCountFormat.format(data.length)} rows. '
          'PDF export is capped at ${_kRowCountFormat.format(limit)} rows so it '
          'stays usable.\n\n'
          'Export the first ${_kRowCountFormat.format(limit)} rows as PDF, or '
          'cancel and use Excel for the complete data set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Export first rows'),
          ),
        ],
      ),
    );
    if (proceed != true) return null;
    return data.take(limit).toList();
  }

  void _exportExcel() async {
    if (_isExportingExcel || _isExportingPdf) return;
    setState(() => _isExportingExcel = true);
    final repo = ref.read(reportsRepositoryProvider);
    final filter = _buildExportFilter();
    final search = _searchQuery;

    try {
      if (_selectedReport == 'Gate Entry Register') {
        var data = await repo.getGateEntryRegister(
          filter,
          q: search.isEmpty ? null : search,
          period: _usesServerPeriod() ? _periodForGateEntryFilter() : null,
        );
        data = _applyGateEntryLocalFilter(data);
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        await _exportService.exportGateEntryRegisterToExcel(data,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'GRN Reconciliation Report') {
        var data = await repo.getGrnReconReport(filter);
        data = data
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.challanNo,
                  item.vendorName,
                  item.vendor,
                  item.poNumber,
                  item.purchaseOrder,
                  item.grnNo,
                  item.materialDocument,
                  item.referenceNo,
                  item.status,
                  item.matchedStatus,
                ]))
            .toList();
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        await _exportService.exportGrnReconReportToExcel(data,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'Exception Report') {
        var data = await repo.getExceptionReport(filter);
        data = data
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.invoiceNo,
                  item.partNo,
                  item.vendorName,
                  item.vendorCode,
                  item.poNumber,
                  item.status,
                  item.description,
                ]))
            .toList();
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        await _exportService.exportExceptionReportToExcel(data,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'Vehicle TAT Report') {
        var data = await repo.getGateEntryRegister(
          filter,
          q: search.isEmpty ? null : search,
          period: _usesServerPeriod() ? _periodForGateEntryFilter() : null,
        );
        data = _applyGateEntryLocalFilter(data);
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        await _exportService.exportVehicleTatReportToExcel(data,
            onProgress: _handleExportProgress);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_exportSuccessMessage('Excel')),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingExcel = false;
          _exportProgress = null;
        });
      }
    }
  }

  void _exportPdf() async {
    if (_isExportingExcel || _isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    final repo = ref.read(reportsRepositoryProvider);
    final filter = _buildExportFilter();
    final search = _searchQuery;

    try {
      if (_selectedReport == 'Gate Entry Register') {
        var data = await repo.getGateEntryRegister(
          filter,
          q: search.isEmpty ? null : search,
          period: _usesServerPeriod() ? _periodForGateEntryFilter() : null,
        );
        data = _applyGateEntryLocalFilter(data);
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        final capped = await _confirmPdfRowLimit(data);
        if (capped == null) return;
        await _exportService.exportGateEntryRegisterToPdf(capped,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'GRN Reconciliation Report') {
        var data = await repo.getGrnReconReport(filter);
        data = data
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.challanNo,
                  item.vendorName,
                  item.vendor,
                  item.poNumber,
                  item.purchaseOrder,
                  item.grnNo,
                  item.materialDocument,
                  item.referenceNo,
                  item.status,
                  item.matchedStatus,
                ]))
            .toList();
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        final capped = await _confirmPdfRowLimit(data);
        if (capped == null) return;
        await _exportService.exportGrnReconReportToPdf(capped,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'Exception Report') {
        var data = await repo.getExceptionReport(filter);
        data = data
            .where((item) => _matchesSearchText(search, [
                  item.gateEntryNo,
                  item.invoiceNo,
                  item.partNo,
                  item.vendorName,
                  item.vendorCode,
                  item.poNumber,
                  item.status,
                  item.description,
                ]))
            .toList();
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        final capped = await _confirmPdfRowLimit(data);
        if (capped == null) return;
        await _exportService.exportExceptionReportToPdf(capped,
            onProgress: _handleExportProgress);
      } else if (_selectedReport == 'Vehicle TAT Report') {
        var data = await repo.getGateEntryRegister(
          filter,
          q: search.isEmpty ? null : search,
          period: _usesServerPeriod() ? _periodForGateEntryFilter() : null,
        );
        data = _applyGateEntryLocalFilter(data);
        if (data.isEmpty) {
          throw Exception('No data available for the selected filters.');
        }
        final capped = await _confirmPdfRowLimit(data);
        if (capped == null) return;
        await _exportService.exportVehicleTatReportToPdf(capped,
            onProgress: _handleExportProgress);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_exportSuccessMessage('PDF')),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _exportProgress = null;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      // showDateRangePicker is full-screen by design — Material specs it for
      // phones. On a desktop window that means one small calendar marooned in
      // a whole page of white. Box it into a dialog-sized surface when there
      // is room; phones keep the native full-screen behaviour.
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width < 700 || child == null) return child ?? const SizedBox.shrink();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
            child: child,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _resetGateEntryPaging();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMob = isMobile(context);
    final dateText = _startDate != null && _endDate != null
        ? (isMob
            ? '${_kShortDateFormat.format(_startDate!)} - ${_kShortDateFormat.format(_endDate!)}'
            : '${_kListDateFormat.format(_startDate!)} - ${_kListDateFormat.format(_endDate!)}')
        : 'Select Date Range';
    final search = _searchQuery;
    // Exception & GRN reports filter search CLIENT-SIDE (see
    // _previewWithCardFilter), so keep it OUT of the provider key. Otherwise
    // every debounced keystroke mints a new autoDispose key and re-runs the
    // full network fetch (incl. the gate-entries enrichment join) just to
    // re-apply an in-memory substring filter. Gate Entry Register searches on
    // the server (q param), so it keeps search in the key.
    final searchForKey = (_selectedReport == 'Gate Entry Register' ||
            _selectedReport == 'Vehicle TAT Report')
        ? search
        : '';
    final query = _ReportQuery(
      reportType: _selectedReport,
      startDate: _startDate,
      endDate: _endDate,
      search: searchForKey.isEmpty ? null : searchForKey,
      gateEntryPeriod:
          _usesServerPeriod() ? _periodForGateEntryFilter() : null,
      gateEntryPage: _gateEntryPage,
      gateEntryLimit: _gateEntryLimit,
    );
    final previewAsync = ref.watch(reportsPreviewProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Exports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(reportsPreviewProvider(query)),
          ),
          const LogoutAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMob ? 12.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildFilterToolbar(context, isMob, dateText),
            const SizedBox(height: 12),
            _buildFilterInfo(context),
            const SizedBox(height: 12),
            previewAsync.when(
              loading: () => SizedBox(
                height: isMob ? 420 : 540,
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: isMob ? 280 : 340,
                child: Center(
                  child: Text(
                    'Failed to load data',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              data: (data) {
                final effectiveData = _previewWithCardFilter(data);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Use effectiveData so the summary reflects the active
                    // in-memory search/card filter (Gate Entry Register keeps
                    // its server-side summary, which _previewWithCardFilter
                    // preserves).
                    _buildSummaryCards(context, isMob, effectiveData),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: isMob ? 430 : 560,
                      child: Card(
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
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: _buildPreview(context, isMob, effectiveData),
                        ),
                      ),
                    ),
                    if (_selectedReport == 'Gate Entry Register' ||
                        _selectedReport == 'Vehicle TAT Report') ...[
                      const SizedBox(height: 12),
                      _buildGateEntryPagination(context, isMob, effectiveData),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterToolbar(BuildContext context, bool isMob, String dateText) {
    InputDecoration inputStyle(String hint, IconData icon) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 860;
            final ultraCompact = width < 620;
            final tiny = width < 500;

            final shortDate = _startDate != null && _endDate != null
                ? '${_kShortDateFormat.format(_startDate!)} - ${_kShortDateFormat.format(_endDate!)}'
                : 'Date';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: inputStyle(
                          'Search vendor / PO / challan / gate no',
                          Icons.search,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: tiny ? 46 : 86,
                      child: OutlinedButton(
                        onPressed: _clearSearch,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: tiny ? 8 : 10,
                            vertical: 10,
                          ),
                        ),
                        child: tiny
                            ? const Icon(Icons.clear, size: 16)
                            : const Text(
                                'Clear',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedReport,
                        isExpanded: true,
                        decoration: inputStyle('Type', Icons.analytics),
                        selectedItemBuilder: (context) => _reportTypes
                            .map((t) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _reportTypeShort(t),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: compact ? 12 : 13),
                                  ),
                                ))
                            .toList(),
                        items: _reportTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedReport = val;
                            _gateEntryCardFilter = _reportAllFilter;
                            // Keep pagination bounded when switching report
                            // types — see comment on the `_gateEntryPage` /
                            // `_gateEntryLimit` field declarations.
                            _gateEntryPage = 1;
                            _gateEntryLimit = 20;
                            _grnPage = 0;
                            _exceptionPage = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          ultraCompact ? shortDate : dateText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: compact ? 12 : 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: (_isExportingExcel || _isExportingPdf)
                            ? null
                            : _exportExcel,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isExportingExcel)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.table_chart, size: 16),
                              if (!tiny) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _isExportingExcel
                                      ? (_exportProgress ?? 'Generating...')
                                      : (ultraCompact ? 'XLS' : 'Excel'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_isExportingExcel || _isExportingPdf)
                            ? null
                            : _exportPdf,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isExportingPdf)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.picture_as_pdf, size: 16),
                              if (!tiny) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _isExportingPdf
                                      ? (_exportProgress ?? 'Generating...')
                                      : 'PDF',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterInfo(BuildContext context) {
    final chips = <Widget>[];
    if (_startDate != null && _endDate != null) {
      chips.add(
        InputChip(
          label: Text(
            'Date: ${_kShortDateFormat.format(_startDate!)} - ${_kShortDateFormat.format(_endDate!)}',
          ),
          onDeleted: () => setState(() {
            _startDate = null;
            _endDate = null;
            _resetGateEntryPaging();
          }),
        ),
      );
    }
    if (_searchQuery.isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Search: $_searchQuery'),
          onDeleted: _clearSearch,
        ),
      );
    }

    String scopeText;
    if (_selectedReport == 'Gate Entry Register') {
      scopeText =
          'Showing Gate Entry data. Search checks vendor, PO, challan, and gate entry number.';
    } else if (_selectedReport == 'Vehicle TAT Report') {
      scopeText =
          'Showing Vehicle TAT derived from gate entries. TAT = Gate Out − Gate In. Dock In/Out will use backend timestamps once available.';
    } else if (_selectedReport == 'GRN Reconciliation Report') {
      scopeText =
          'Showing Reconciliation data. Search checks vendor, PO, challan, gate entry number, and GRN fields.';
    } else {
      scopeText =
          'Showing Exception data. Search checks gate entry number, PO, status, and description.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scopeText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    bool isMob,
    _ReportPreviewData data,
  ) {
    final tiles = <Widget>[];

    if (_selectedReport == 'Gate Entry Register' ||
        _selectedReport == 'Vehicle TAT Report') {
      final summary = data.gateEntrySummary;

      final cards = [
        _gateEntryFilterCard(
          context,
          title: _gateInFilter,
          value: '${summary.gateIn}',
          subtitle: 'Incoming',
          icon: Icons.login,
          accent: Colors.indigo,
          isSelected: _gateEntryCardFilter == _gateInFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _gateInFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: _gateOutFilter,
          value: '${summary.gateOut}',
          subtitle: 'Outgoing',
          icon: Icons.logout,
          accent: Colors.deepOrange,
          isSelected: _gateEntryCardFilter == _gateOutFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _gateOutFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: 'Total',
          value: '${summary.total}',
          subtitle: 'All entries',
          icon: Icons.dashboard_customize,
          accent: Colors.blueGrey,
          isSelected: _gateEntryCardFilter == _reportAllFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _reportAllFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: _todayFilter,
          value: '${summary.today}',
          subtitle: 'Entries today',
          icon: Icons.today,
          accent: Colors.teal,
          isSelected: _gateEntryCardFilter == _todayFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _todayFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: _yesterdayFilter,
          value: '${summary.yesterday}',
          subtitle: 'Yesterday',
          icon: Icons.history,
          accent: Colors.purple,
          isSelected: _gateEntryCardFilter == _yesterdayFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _yesterdayFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: _thisWeekFilter,
          value: '${summary.thisWeek}',
          subtitle: 'This week',
          icon: Icons.view_week,
          accent: Colors.cyan,
          isSelected: _gateEntryCardFilter == _thisWeekFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _thisWeekFilter;
            _resetGateEntryPaging();
          }),
        ),
        _gateEntryFilterCard(
          context,
          title: _thisMonthFilter,
          value: '${summary.thisMonth}',
          subtitle: 'This month',
          icon: Icons.calendar_month,
          accent: Colors.amber.shade800,
          isSelected: _gateEntryCardFilter == _thisMonthFilter,
          onTap: () => setState(() {
            _gateEntryCardFilter = _thisMonthFilter;
            _resetGateEntryPaging();
          }),
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final spacing = isMob ? 8.0 : 10.0;
          final columns = isMob ? 2 : 5;
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
    } else if (_selectedReport == 'GRN Reconciliation Report') {
      int matched = 0;
      int exception = 0;
      int pending = 0;
      double qtyDiffTotal = 0;
      for (final item in data.grnRecons) {
        final key =
            '${item.matchedStatus ?? ''} ${item.status ?? ''}'.toLowerCase();
        if (key.contains('match')) {
          matched++;
        } else if (key.contains('exception') || key.contains('mismatch')) {
          exception++;
        } else {
          pending++;
        }
        qtyDiffTotal += (item.quantityDiff ?? 0).abs();
      }
      tiles.addAll([
        _summaryCard(context, 'Total Records', data.grnRecons.length.toString(),
            Icons.receipt_long, Colors.blue),
        _summaryCard(
            context, 'Matched', matched.toString(), Icons.check_circle, Colors.green),
        _summaryCard(context, 'Exceptions', exception.toString(),
            Icons.warning_amber, Colors.redAccent),
        _summaryCard(
            context, 'Pending', pending.toString(), Icons.pending_actions, Colors.orange),
        _summaryCard(
          context,
          'Qty Diff Total',
          qtyDiffTotal.toStringAsFixed(
              qtyDiffTotal == qtyDiffTotal.roundToDouble() ? 0 : 2),
          Icons.balance,
          Colors.purple,
        ),
      ]);
    } else {
      int resolved = 0;
      int open = 0;
      for (final item in data.exceptions) {
        final key = item.status.toLowerCase();
        if (key.contains('resolve') ||
            key.contains('closed') ||
            key.contains('done')) {
          resolved++;
        } else {
          open++;
        }
      }
      tiles.addAll([
        _summaryCard(context, 'Total Exceptions', data.exceptions.length.toString(),
            Icons.error_outline, Colors.red),
        _summaryCard(
            context, 'Open', open.toString(), Icons.report_problem, Colors.orange),
        _summaryCard(
            context, 'Resolved', resolved.toString(), Icons.verified, Colors.green),
      ]);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobileWidth = (screenWidth - 44) / 2;
    final cardWidth = isMob ? (mobileWidth < 160 ? double.infinity : mobileWidth) : 200.0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles
          .map(
            (tile) => SizedBox(
              width: cardWidth,
              child: tile,
            ),
          )
          .toList(),
    );
  }

  Widget _buildGateEntryPagination(
    BuildContext context,
    bool isMob,
    _ReportPreviewData data,
  ) {
    final pagination = data.gateEntryPagination;
    final visibleCount = data.gateEntries.length;
    final total = pagination?.total ??
        (data.gateEntrySummary.total > 0
            ? data.gateEntrySummary.total
            : data.gateEntries.length);
    final from = pagination == null
        ? (visibleCount == 0 ? 0 : 1)
        : (pagination.total == 0 ? 0 : ((pagination.page - 1) * pagination.limit) + 1);
    final to = pagination == null
        ? visibleCount
        : (pagination.total == 0
            ? 0
            : (((pagination.page - 1) * pagination.limit) + visibleCount)
                .clamp(0, pagination.total));
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
                  pagination == null
                      ? 'Showing all $visibleCount of $total'
                      : 'Showing $from-$to of ${pagination.total}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
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
                    setState(() {
                      _gateEntryLimit = value;
                      _gateEntryPage = 1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pagination != null && pagination.hasPrev
                            ? () => setState(() => _gateEntryPage = pagination.page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: pagination != null && pagination.hasNext
                            ? () => setState(() => _gateEntryPage = pagination.page + 1)
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
                  pagination == null
                      ? 'Showing all $visibleCount of $total'
                      : 'Showing $from-$to of ${pagination.total}',
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
                      setState(() {
                        _gateEntryLimit = value;
                        _gateEntryPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: pagination != null && pagination.hasPrev
                      ? () => setState(() => _gateEntryPage = pagination.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: pagination != null && pagination.hasNext
                      ? () => setState(() => _gateEntryPage = pagination.page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
    );
  }

  Widget _gateEntryFilterCard(
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
                child: Icon(icon, size: 18, color: accent),
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

  Widget _summaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    bool isMob,
    _ReportPreviewData data,
  ) {
    if (_selectedReport == 'Gate Entry Register' ||
        _selectedReport == 'Vehicle TAT Report') {
      if (data.gateEntries.isEmpty) {
        return _buildEmptyState(context);
      }
      return isMob
          ? _buildGateEntryMobile(context, data.gateEntries)
          : _buildGateEntryTable(context, data.gateEntries);
    }

    if (_selectedReport == 'GRN Reconciliation Report') {
      if (data.grnRecons.isEmpty) {
        return _buildEmptyState(context);
      }
      return isMob
          ? _buildGrnMobile(context, data.grnRecons)
          : _buildGrnTable(context, data.grnRecons);
    }

    if (data.exceptions.isEmpty) {
      return _buildEmptyState(context);
    }
    return isMob
        ? _buildExceptionMobile(context, data.exceptions)
        : _buildExceptionTable(context, data.exceptions);
  }

  /// Compact pager for the client-windowed preview tables.
  Widget _clientTablePager({
    required int total,
    required int page,
    required ValueChanged<int> onPage,
  }) {
    if (total <= _clientPageSize) return const SizedBox.shrink();
    final pageCount = ((total - 1) ~/ _clientPageSize) + 1;
    final first = page * _clientPageSize + 1;
    final last = (first + _clientPageSize - 1).clamp(first, total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Showing $first-$last of $total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 0 ? () => onPage(page - 1) : null,
          ),
          Text('${page + 1} / $pageCount'),
          IconButton(
            tooltip: 'Next',
            icon: const Icon(Icons.chevron_right),
            onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        'No records found',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildGateEntryTable(
      BuildContext context, List<GateEntryReportItem> items) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Gate Entry No')),
            DataColumn(label: Text('Direction')),
            DataColumn(label: Text('Invoice / Challan No')),
            DataColumn(label: Text('PO No')),
            DataColumn(label: Text('LR No')),
            DataColumn(label: Text('Date And Time')),
            DataColumn(label: Text('Material')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Transporter')),
            DataColumn(label: Text('Vehicle No')),
            DataColumn(label: Text('Status')),
          ],
          rows: items
              .map(
                (e) => DataRow(cells: [
                  DataCell(Text(e.gateEntryNo)),
                  DataCell(Text(e.direction)),
                  DataCell(Text(e.challanNo)),
                  DataCell(Text(e.poNumber)),
                  DataCell(Text(e.lrNo.isEmpty ? '-' : e.lrNo)),
                  DataCell(Text(_kListDateFormat.format(e.date))),
                  DataCell(Text(e.material)),
                  DataCell(Text(e.qty.toString())),
                  DataCell(Text(e.vendor)),
                  DataCell(Text(e.transporter)),
                  DataCell(Text(e.vehicleNo)),
                  DataCell(StatusChip(
                    label: e.status,
                    color: _statusColor(e.status),
                  )),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildGateEntryMobile(
      BuildContext context, List<GateEntryReportItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = items[index];
        final isGateIn = _isGateEntryGateIn(e);
        final accent = isGateIn ? Colors.indigo : Colors.deepOrange;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGateIn ? Icons.login : Icons.logout,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.gateEntryNo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${e.direction} - ${e.challanNo}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(context, e.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.store_outlined,
                      label: 'Vendor',
                      value: e.vendor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'PO / LR',
                      value: '${e.poNumber} / ${e.lrNo.isEmpty ? '-' : e.lrNo}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Qty / Material',
                      value: '${e.qty} - ${e.material}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.local_shipping_outlined,
                      label: 'Vehicle',
                      value: e.vehicleNo.isEmpty ? 'N/A' : e.vehicleNo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                      _kListDateFormat.format(e.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reportInfoCell(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
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
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                  maxLines: maxLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    final normalized = status.trim();
    if (normalized.isEmpty) return '-';
    return normalized
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _firstNonEmpty(List<String?> values, {String fallback = '-'}) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  String _formatApiDate(String raw) {
    if (raw.trim().isEmpty || raw == '-') return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _kListDateFormat.format(parsed.toLocal());
  }

  String _reportTypeShort(String reportType) {
    switch (reportType) {
      case 'Gate Entry Register':
        return 'Gate Entry';
      case 'GRN Reconciliation Report':
        return 'GRN Reco';
      case 'Exception Report':
        return 'Exception';
      case 'Vehicle TAT Report':
        return 'Vehicle TAT';
      default:
        return reportType;
    }
  }

  Widget _buildGrnTable(BuildContext context, List<GrnReconReportItem> items) {
    // DataTable builds every cell eagerly — it does not virtualise. The
    // GRN report is 45 columns wide and the server returns up to 500 rows,
    // which is ~22,500 DataCells in one synchronous build. That froze the
    // web UI hard enough that Chrome could not even capture a frame.
    // Render one page at a time instead.
    final pageCount =
        items.isEmpty ? 1 : ((items.length - 1) ~/ _clientPageSize) + 1;
    final page = _grnPage.clamp(0, pageCount - 1);
    final window =
        items.skip(page * _clientPageSize).take(_clientPageSize).toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Gate Entry No')),
            DataColumn(label: Text('GRN No')),
            DataColumn(label: Text('PO No')),
            DataColumn(label: Text('Challan No')),
            DataColumn(label: Text('Matched Status')),
            DataColumn(label: Text('Qty Diff')),
            DataColumn(label: Text('Vendor Name')),
            DataColumn(label: Text('Reconciled At')),
            DataColumn(label: Text('Sr No')),
            DataColumn(label: Text('Remarks')),
            DataColumn(label: Text('Duplicate Reference')),
            DataColumn(label: Text('Dublicate')),
            DataColumn(label: Text('Reference No')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Document Date')),
            DataColumn(label: Text('Quantity')),
            DataColumn(label: Text('Material')),
            DataColumn(label: Text('Material Document')),
            DataColumn(label: Text('Posting Date')),
            DataColumn(label: Text('Plant')),
            DataColumn(label: Text('Material Description')),
            DataColumn(label: Text('Movement Type')),
            DataColumn(label: Text('Movement Type Text')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Purchase Order')),
            DataColumn(label: Text('Document Header Text')),
            DataColumn(label: Text('User Name')),
            DataColumn(label: Text('Entry Date')),
            DataColumn(label: Text('Time Of Entry')),
            DataColumn(label: Text('Amount In Local Currency')),
            DataColumn(label: Text('Qty In Opun')),
            DataColumn(label: Text('Qty In Order Unit')),
            DataColumn(label: Text('Local Time')),
            DataColumn(label: Text('Local Date')),
            DataColumn(label: Text('Shift')),
            DataColumn(label: Text('Store Remarks')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aging')),
            DataColumn(label: Text('MDR')),
            DataColumn(label: Text('Scanning Invoice Status')),
            DataColumn(label: Text('Scanning Date')),
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Source Vendor Name')),
            DataColumn(label: Text('Buyer Name')),
            DataColumn(label: Text('Maker Checker')),
          ],
          rows: window
              .map(
                (e) => DataRow(cells: [
                  DataCell(Text(e.gateEntryNo ?? '')),
                  DataCell(Text(e.grnNo ?? '')),
                  DataCell(Text(e.poNumber ?? '')),
                  DataCell(Text(e.challanNo ?? '')),
                  DataCell(StatusChip(
                    label: e.matchedStatus ?? '-',
                    color: _statusColor(e.matchedStatus ?? ''),
                  )),
                  DataCell(Text(e.quantityDiff?.toString() ?? '')),
                  DataCell(Text(e.vendorName ?? '')),
                  DataCell(Text(e.reconciledAt ?? '')),
                  DataCell(Text(e.srNo ?? '')),
                  DataCell(Text(e.remarks ?? '')),
                  DataCell(Text(e.duplicateReference ?? '')),
                  DataCell(Text(e.dublicate ?? '')),
                  DataCell(Text(e.referenceNo ?? '')),
                  DataCell(Text(e.reference ?? '')),
                  DataCell(Text(e.documentDate ?? '')),
                  DataCell(Text(e.quantity ?? '')),
                  DataCell(Text(e.material ?? '')),
                  DataCell(Text(e.materialDocument ?? '')),
                  DataCell(Text(e.postingDate ?? '')),
                  DataCell(Text(e.plant ?? '')),
                  DataCell(Text(e.materialDescription ?? '')),
                  DataCell(Text(e.movementType ?? '')),
                  DataCell(Text(e.movementTypeText ?? '')),
                  DataCell(Text(e.supplier ?? '')),
                  DataCell(Text(e.purchaseOrder ?? '')),
                  DataCell(Text(e.documentHeaderText ?? '')),
                  DataCell(Text(e.userName ?? '')),
                  DataCell(Text(e.entryDate ?? '')),
                  DataCell(Text(e.timeOfEntry ?? '')),
                  DataCell(Text(e.amountInLocalCurrency ?? '')),
                  DataCell(Text(e.qtyInOpun ?? '')),
                  DataCell(Text(e.qtyInOrderUnit ?? '')),
                  DataCell(Text(e.localTime ?? '')),
                  DataCell(Text(e.localDate ?? '')),
                  DataCell(Text(e.shift ?? '')),
                  DataCell(Text(e.storeRemarks ?? '')),
                  DataCell(Text(e.status ?? '')),
                  DataCell(Text(e.aging ?? '')),
                  DataCell(Text(e.mdr ?? '')),
                  DataCell(Text(e.scanningInvoiceStatus ?? '')),
                  DataCell(Text(e.scanningDate ?? '')),
                  DataCell(Text(e.vendor ?? '')),
                  DataCell(Text(e.sourceVendorName ?? '')),
                  DataCell(Text(e.buyerName ?? '')),
                  DataCell(Text(e.makerChecker ?? '')),
                ]),
              )
              .toList(),
        ),
          ),
          _clientTablePager(total: items.length, page: page, onPage: (p) => setState(() => _grnPage = p)),
        ],
      ),
    );
  }

  Widget _buildGrnMobile(BuildContext context, List<GrnReconReportItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = items[index];
        final gateEntryNo = _firstNonEmpty([
          e.gateEntryNo,
          e.referenceNo,
          e.reference,
        ], fallback: '-');
        final poNo = _firstNonEmpty([
          e.poNumber,
          e.purchaseOrder,
        ], fallback: '-');
        final grnNo = _firstNonEmpty([
          e.grnNo,
          e.materialDocument,
        ], fallback: '-');
        final challanNo = _firstNonEmpty([
          e.challanNo,
          e.referenceNo,
          e.documentHeaderText,
        ], fallback: '-');
        final vendor = _firstNonEmpty([
          e.vendorName,
          e.vendor,
          e.sourceVendorName,
          e.supplier,
        ], fallback: '-');
        final reconciledAt = _firstNonEmpty([
          e.reconciledAt,
          e.entryDate,
          e.postingDate,
          e.localDate,
        ], fallback: '-');
        final reconciledAtText = _formatApiDate(reconciledAt);
        final material = _firstNonEmpty([
          e.material,
          e.materialDescription,
        ], fallback: '-');
        final reasonCode = _firstNonEmpty([
          e.mdr,
        ], fallback: '-');
        final reconciledBy = _firstNonEmpty([
          e.userName,
          e.makerChecker,
        ], fallback: '-');
        final status = _firstNonEmpty([
          e.matchedStatus,
          e.status,
          e.scanningInvoiceStatus,
        ], fallback: 'Pending');
        final accent = _statusColor(status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.rule_folder_outlined, size: 18, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gateEntryNo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'PO: $poNo',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _statusPill(context, status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'GRN / Challan',
                      value: '$grnNo / $challanNo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.balance,
                      label: 'Qty Diff',
                      value: e.quantityDiff != null ? e.quantityDiff.toString() : '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.store_outlined,
                      label: 'Vendor',
                      value: vendor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.access_time,
                      label: 'Reconciled',
                      value: reconciledAtText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.code_outlined,
                      label: 'Reason Code',
                      value: reasonCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.person_outline,
                      label: 'Reconciled By',
                      value: reconciledBy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _reportInfoCell(
                context,
                icon: Icons.inventory_2_outlined,
                label: 'Material',
                value: material,
                maxLines: 2,
              ),
              if (e.remarks?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _reportInfoCell(
                  context,
                  icon: Icons.notes_outlined,
                  label: 'Remarks',
                  value: e.remarks!,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExceptionTable(
      BuildContext context, List<ExceptionReportItem> items) {
    // DataTable builds every cell eagerly — it does not virtualise. The
    // GRN report is 45 columns wide and the server returns up to 500 rows,
    // which is ~22,500 DataCells in one synchronous build. That froze the
    // web UI hard enough that Chrome could not even capture a frame.
    // Render one page at a time instead.
    final pageCount =
        items.isEmpty ? 1 : ((items.length - 1) ~/ _clientPageSize) + 1;
    final page = _exceptionPage.clamp(0, pageCount - 1);
    final window =
        items.skip(page * _clientPageSize).take(_clientPageSize).toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Gate Entry No')),
            DataColumn(label: Text('Invoice No')),
            DataColumn(label: Text('Part No')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Vendor Code')),
            DataColumn(label: Text('Exception Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
          ],
          rows: window
              .map(
                (e) => DataRow(cells: [
                  DataCell(Text(e.gateEntryNo.isEmpty ? '-' : e.gateEntryNo)),
                  DataCell(Text(e.invoiceNo.isEmpty ? '-' : e.invoiceNo)),
                  DataCell(Text(e.partNo.isEmpty ? '-' : e.partNo)),
                  DataCell(Text(e.qty.toString())),
                  DataCell(Text(e.vendorName.isEmpty ? '-' : e.vendorName)),
                  DataCell(Text(e.vendorCode.isEmpty ? '-' : e.vendorCode)),
                  DataCell(Text(e.description)),
                  DataCell(StatusChip(
                    label: e.status,
                    color: _statusColor(e.status),
                  )),
                  DataCell(Text(_kListDateFormat.format(e.createdAt))),
                ]),
              )
              .toList(),
        ),
          ),
          _clientTablePager(total: items.length, page: page, onPage: (p) => setState(() => _exceptionPage = p)),
        ],
      ),
    );
  }

  Widget _buildExceptionMobile(
      BuildContext context, List<ExceptionReportItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = items[index];
        final accent = _statusColor(e.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.error_outline, size: 18, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.gateEntryNo.isEmpty ? '-' : e.gateEntryNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusPill(context, e.status),
                ],
              ),
              const SizedBox(height: 10),
              _reportInfoCell(
                context,
                icon: Icons.warning_amber_outlined,
                label: 'Exception Type',
                value: e.description,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Invoice No',
                      value: e.invoiceNo.isEmpty ? '-' : e.invoiceNo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.numbers_outlined,
                      label: 'Part No',
                      value: e.partNo.isEmpty ? '-' : e.partNo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.factory_outlined,
                      label: 'Vendor',
                      value: e.vendorName.isEmpty ? '-' : e.vendorName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.qr_code_2_outlined,
                      label: 'Vendor Code',
                      value: e.vendorCode.isEmpty ? '-' : e.vendorCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'PO Number',
                      value: e.poNumber.isEmpty ? '-' : e.poNumber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _reportInfoCell(
                      context,
                      icon: Icons.tag_outlined,
                      label: 'Qty',
                      value: e.qty.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _reportInfoCell(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Created',
                value: _kDayDateFormat.format(e.createdAt),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    final key = status.toLowerCase();
    if (key.contains('match')) return Colors.green;
    if (key.contains('approved') || key.contains('resolved')) return Colors.green;
    if (key.contains('closed') || key.contains('done')) return Colors.grey;
    if (key.contains('pending')) return Colors.orange;
    if (key.contains('exception') || key.contains('mismatch')) {
      return Colors.red;
    }
    return Colors.blueGrey;
  }
}


