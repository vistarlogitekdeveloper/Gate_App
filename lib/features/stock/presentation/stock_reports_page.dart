import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../../reports/domain/services/report_export_service.dart';
import '../data/stock_repository.dart';
import '../domain/stock_report.dart';
import 'stock_widgets.dart';

/// Stock reports (managers and admins): what came in, what was dispatched,
/// and the balance as of a date. Preview here, download as Excel or PDF.
class StockReportsPage extends ConsumerStatefulWidget {
  const StockReportsPage({super.key, this.initial = StockReportKind.balance});
  final StockReportKind initial;

  @override
  ConsumerState<StockReportsPage> createState() => _StockReportsPageState();
}

class _StockReportsPageState extends ConsumerState<StockReportsPage> {
  static const _previewRows = 100;
  static final _day = DateFormat('dd MMM yyyy');
  static final _fileDay = DateFormat('dd-MM-yyyy');

  final _export = ReportExportService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late StockReportKind _kind;
  late DateTimeRange _range;
  DateTime _asOf = DateTime.now();
  bool _openOnly = true;
  String _search = '';
  bool _loading = false;
  String? _error;
  StockReportResult? _result;
  int _seq = 0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial;
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day));
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isToday(DateTime d) => DateUtils.isSameDay(d, DateTime.now());

  /// End of the chosen day, or now for today.
  DateTime get _asOfInstant =>
      _isToday(_asOf) ? DateTime.now() : DateTime(_asOf.year, _asOf.month, _asOf.day, 23, 59, 59, 999);

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(stockRepositoryProvider);
      final result = _kind.usesRange
          ? await repo.report(_kind,
              from: _range.start,
              to: DateTime(_range.end.year, _range.end.month, _range.end.day).add(const Duration(days: 1)),
              search: _search)
          : await repo.report(_kind, asOf: _asOfInstant, search: _search, openOnly: _openOnly);
      if (!mounted || seq != _seq) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  Future<void> _pickAsOf() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _asOf,
      helpText: 'Balance as of',
    );
    if (picked == null) return;
    setState(() => _asOf = picked);
    _load();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _search = v.trim();
      _load();
    });
  }

  String get _period => _kind.usesRange
      ? '${_day.format(_range.start)} – ${_day.format(_range.end)}'
      : 'as of ${_isToday(_asOf) ? 'now (${_day.format(_asOf)})' : _day.format(_asOf)}';

  String get _fileSuffix => _kind.usesRange
      ? '${_fileDay.format(_range.start)}_to_${_fileDay.format(_range.end)}'
      : 'as_of_${_fileDay.format(_asOf)}';

  /// Rows plus a Total row under the quantity columns.
  List<List<Object?>> _tableRows(List<Map<String, dynamic>> rows) {
    final cols = stockReportColumns(_kind);
    final out = [for (final r in rows) [for (final c in cols) c.value(r)]];
    if (rows.isNotEmpty) {
      final totals = stockReportTotals(_kind, rows);
      out.add([for (var i = 0; i < cols.length; i++) i == 0 ? 'Total' : totals[i]]);
    }
    return out;
  }

  Future<void> _exportExcel() async {
    final result = _result;
    if (result == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await _export.exportTableToExcel(
        fileName: '${_kind.fileBase}_$_fileSuffix.xlsx',
        sheetName: _kind.short.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ''),
        headers: [for (final c in stockReportColumns(_kind)) c.header],
        rows: _tableRows(result.rows),
      );
    } catch (e) {
      _snack('Could not export: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _exportPdf() async {
    final result = _result;
    if (result == null || _exporting) return;
    var rows = result.rows;
    const limit = ReportExportService.pdfRowLimit;
    if (rows.length > limit) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large report'),
          content: Text('This report has ${rows.length} rows. A PDF holds the first $limit; '
              'use Excel for all of them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('PDF of first $limit')),
          ],
        ),
      );
      if (ok != true) return;
      rows = rows.sublist(0, limit);
    }
    setState(() => _exporting = true);
    try {
      await _export.exportTableToPdf(
        fileName: '${_kind.fileBase}_$_fileSuffix.pdf',
        title: '${_kind.title} · $_period',
        headers: [for (final c in stockReportColumns(_kind)) c.header],
        rows: [for (final r in _tableRows(rows)) [for (final v in r) stockReportCellText(v)]],
      );
    } catch (e) {
      _snack('Could not export: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    }
    if (mounted) setState(() => _exporting = false);
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.redAccent : null,
      content: Text(text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final result = _result;
    final rows = result?.rows ?? const <Map<String, dynamic>>[];
    final cols = stockReportColumns(_kind);
    final totals = stockReportTotals(_kind, rows);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Reports')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(mob ? 12 : 24, 16, mob ? 12 : 24, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in StockReportKind.values)
                ChoiceChip(
                  label: Text(k.short),
                  selected: _kind == k,
                  onSelected: (_) {
                    setState(() {
                      _kind = k;
                      _result = null;
                    });
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _kind.usesRange ? _pickRange : _pickAsOf,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(_period),
              ),
              if (!_kind.usesRange)
                FilterChip(
                  label: const Text('Only items with stock left'),
                  selected: _openOnly,
                  onSelected: (v) {
                    setState(() => _openOnly = v);
                    _load();
                  },
                ),
              SizedBox(
                width: mob ? double.infinity : 360,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Count sheet, invoice, DC, vendor, customer, vehicle, PO, material…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _loading
                      ? 'Loading…'
                      : result == null
                          ? ''
                          : '${rows.length} row${rows.length == 1 ? '' : 's'} · $_period',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: result == null || rows.isEmpty || _exporting ? null : _exportExcel,
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: const Text('Excel'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: result == null || rows.isEmpty || _exporting ? null : _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
              ),
            ],
          ),
          if (result?.truncated ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Only the first ${result!.maxRows} rows are included. Choose fewer dates or search to narrow it.',
                style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          if (_loading && result == null)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_error != null)
            StockMessage(
              icon: Icons.error_outline,
              color: theme.colorScheme.error,
              text: _error!,
              action: TextButton(onPressed: _load, child: const Text('Try again')),
            )
          else if (result != null && rows.isEmpty)
            StockMessage(icon: Icons.inventory_2_outlined, text: 'Nothing for $_period${_search.isEmpty ? '' : ' matching "$_search"'}.')
          else if (result != null)
            VistarCard(
              padding: const EdgeInsets.all(4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 44,
                  columnSpacing: 18,
                  columns: [
                    for (final c in cols) DataColumn(label: Text(c.header), numeric: c.numeric),
                  ],
                  rows: [
                    for (final r in rows.take(_previewRows))
                      DataRow(cells: [for (final c in cols) DataCell(Text(stockReportCellText(c.value(r))))]),
                    DataRow(
                      color: WidgetStatePropertyAll(theme.colorScheme.primary.withValues(alpha: 0.06)),
                      cells: [
                        for (var i = 0; i < cols.length; i++)
                          DataCell(Text(
                            i == 0 ? 'Total' : stockReportCellText(totals[i]),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (rows.length > _previewRows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Showing the first $_previewRows of ${rows.length} rows (the total covers all). '
                  'Download Excel for every row.', style: muted),
            ),
        ],
      ),
    );
  }
}
