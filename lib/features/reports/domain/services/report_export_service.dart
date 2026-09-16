import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exception_report_item.dart';
import '../models/report_models.dart';
import 'export_file_helper.dart';
import 'fast_xlsx.dart';

/// Headers plus rows for one worksheet. The `_build*ExcelRows` helpers below
/// produce this shape; [buildXlsx] turns it into an .xlsx.
typedef _SheetData = ({
  String sheetName,
  List<String> headers,
  List<List<Object?>> rows,
});

/// Progress signal for a long export: (rowsWritten, totalRows).
typedef ExportProgress = void Function(int rowsWritten, int totalRows);

class ReportExportService {
  final ExportFileHelper _fileHelper = getExportFileHelper();

  /// Maximum number of rows a PDF export will render.
  ///
  /// A PDF lays every row out as vector text, so it costs far more per row
  /// than a spreadsheet. On web that layout runs on the UI thread, because
  /// foundation's `compute` does not spawn an isolate there (its web
  /// implementation is `await null; return callback(message);`), so a slow
  /// PDF reads to the user as a hang.
  ///
  /// Measured on the Dart VM after the chunking fix in [_pdfTableChunks]
  /// (web is several times slower again):
  ///
  ///     500 rows -> 0.8 s      2,000 rows ->  4.6 s
  ///   1,000 rows -> 0.9 s     17,421 rows -> 45.5 s
  ///
  /// 1,000 keeps a browser export to a few seconds. Callers must cap the list
  /// at this many rows AND tell the user that they did — silently dropping
  /// rows from a report is worse than refusing. Excel has no such limit (it
  /// writes all 17,421 rows in well under a second) and is the right format
  /// for the full data set.
  static const int pdfRowLimit = 1000;

  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Future<void> _saveSheet(
    _SheetData sheet,
    String fileName,
    ExportProgress? onProgress,
  ) async {
    final bytes = await buildXlsx(
      headers: sheet.headers,
      rows: sheet.rows,
      sheetName: sheet.sheetName,
      onProgress: onProgress,
    );
    await _fileHelper.saveAndShare(
      fileName: fileName,
      bytes: bytes,
      mimeType: _xlsxMime,
    );
  }

  /// Test seam: runs the real PDF pipeline without touching the platform
  /// file/share plumbing, which is unavailable under flutter_test. Exists so
  /// the incremental renderer keeps a regression test on production code.
  @visibleForTesting
  Future<Uint8List> buildGateEntryPdfBytesForTest(
    List<GateEntryReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _buildGateEntryPdfBytes(data, onProgress: onProgress);

  Future<void> _savePdf(Uint8List bytes, String fileName) =>
      _fileHelper.saveAndShare(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
      );

  Future<void> exportGateEntryRegisterToExcel(
    List<GateEntryReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(_buildGateEntryExcelRows(data), 'GateEntryRegister.xlsx',
          onProgress);

  Future<void> exportGateEntryRegisterToPdf(
    List<GateEntryReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildGateEntryPdfBytes(data, onProgress: onProgress),
          'GateEntryRegister.pdf');

  Future<void> exportGrnReconReportToExcel(
    List<GrnReconReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(_buildGrnReconExcelRows(data), 'GRN_Reconciliation.xlsx',
          onProgress);

  Future<void> exportGrnReconReportToPdf(
    List<GrnReconReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildGrnReconPdfBytes(data, onProgress: onProgress),
          'GRN_Reconciliation.pdf');

  Future<void> exportPendingGrnReportToExcel(
    List<PendingGrnReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(
          _buildPendingGrnExcelRows(data), 'Pending_GRN.xlsx', onProgress);

  Future<void> exportPendingGrnReportToPdf(
    List<PendingGrnReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildPendingGrnPdfBytes(data, onProgress: onProgress),
          'Pending_GRN.pdf');

  Future<void> exportAuditTrailReportToExcel(
    List<AuditTrailReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(
          _buildAuditTrailExcelRows(data), 'Audit_Trail.xlsx', onProgress);

  Future<void> exportAuditTrailReportToPdf(
    List<AuditTrailReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildAuditTrailPdfBytes(data, onProgress: onProgress),
          'Audit_Trail.pdf');

  Future<void> exportExceptionReportToExcel(
    List<ExceptionReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(_buildExceptionExcelRows(data), 'Exception_Report.xlsx',
          onProgress);

  Future<void> exportExceptionReportToPdf(
    List<ExceptionReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildExceptionPdfBytes(data, onProgress: onProgress),
          'Exception_Report.pdf');

  // Vehicle TAT is derived on the client from the gate entry register (Gate
  // In = entry.date, Gate Out = entry.gateOutDate). The Excel format shared
  // by the warehouse team uses Dock In / Dock Out, which the backend does not
  // yet expose — see backend_api_spec.md for the pending fields. For now we
  // report Gate-TAT (Gate In → Gate Out) with the same shift / after-hours /
  // "With TAT" / "Out of TAT" derivations as the shared workbook.
  Future<void> exportVehicleTatReportToExcel(
    List<GateEntryReportItem> data, {
    ExportProgress? onProgress,
  }) =>
      _saveSheet(_buildVehicleTatExcelRows(data), 'Vehicle_TAT_Report.xlsx',
          onProgress);

  Future<void> exportVehicleTatReportToPdf(
    List<GateEntryReportItem> data, {
    ExportProgress? onProgress,
  }) async =>
      _savePdf(await _buildVehicleTatPdfBytes(data, onProgress: onProgress),
          'Vehicle_TAT_Report.pdf');
}

// ---------------------------------------------------------------------------
// Row builders and PDF helpers
//
// The `_build*ExcelRows` helpers only shape data — buildXlsx (fast_xlsx.dart)
// does the writing, chunked so the web UI keeps painting. They are NOT run
// through `compute`: that buys nothing on web, where compute has no isolate
// to spawn and runs the callback inline on the UI thread.
//
// The PDF builders still go through `compute`, which is a real isolate on
// mobile and a plain inline call on web. That is only safe because callers
// cap the row list at ReportExportService.pdfRowLimit first.
//
// Every PDF uses pw.MultiPage so rows that don't fit on one page paginate
// instead of producing a blank document. Wide reports run in landscape with
// tighter cell fonts so all columns stay readable.
// ---------------------------------------------------------------------------

final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
final DateFormat _timeFormat = DateFormat('hh:mm a');

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return _dateFormat.format(value.toLocal());
}

String _formatTime(DateTime? value) {
  if (value == null) return '';
  return _timeFormat.format(value.toLocal());
}

String _formatTurnaroundTime(DateTime gateIn, DateTime? gateOut) {
  if (gateOut == null || gateOut.isBefore(gateIn)) return '';

  final duration = gateOut.difference(gateIn);
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');
  return parts.join(' ');
}

pw.Widget _pdfTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _pdfEmpty() {
  return pw.Center(
    child: pw.Text(
      'No records found',
      style: const pw.TextStyle(fontSize: 12),
    ),
  );
}

/// Rows per page-sized chunk. Roughly one landscape A4 page of table.
const int _pdfChunkRows = 40;

/// Column weights that approximate the old auto-sizing, computed once for the
/// whole report so every chunk lines up into one continuous-looking table.
/// Left to itself each Table sizes columns from its own rows, and the seams
/// between chunks would show.
Map<int, pw.TableColumnWidth> _pdfColumnWidths(
  List<String> headers,
  List<List<String>> rows,
) {
  final sample = rows.length > 200 ? rows.sublist(0, 200) : rows;
  final widths = <int, pw.TableColumnWidth>{};
  for (var c = 0; c < headers.length; c++) {
    var widest = headers[c].length;
    for (final row in sample) {
      if (c < row.length && row[c].length > widest) widest = row[c].length;
    }
    widths[c] = pw.FlexColumnWidth(widest.clamp(4, 28).toDouble());
  }
  return widths;
}

pw.Widget _pdfTable({
  required List<String> headers,
  required List<List<String>> rows,
  required Map<int, pw.TableColumnWidth> widths,
  double cellFontSize = 7,
  double headerFontSize = 8,
}) {
  // ignore: deprecated_member_use
  return pw.Table.fromTextArray(
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: headerFontSize,
    ),
    cellStyle: pw.TextStyle(fontSize: cellFontSize),
    cellAlignment: pw.Alignment.centerLeft,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    columnWidths: widths,
    headers: headers,
    data: rows,
  );
}

/// Renders a titled table report one page-sized chunk at a time.
///
/// Flutter web has no isolates, so both widget layout and `pdf.save()` run on
/// the UI thread — building the whole report as one MultiPage froze the tab
/// for as long as it took, which is what users reported as a stuck export.
/// Two things fix that:
///
///  * One `addPage` per chunk instead of a single giant table. MultiPage
///    re-measures a child from scratch for every page it spans, so one table
///    holding every row cost O(rows x pages): 2,000 rows took 81 s where 500
///    took 4 s. Per-chunk pages make each measurement cheap.
///  * An `await` between pages. That yields a macrotask, which is what lets
///    the browser actually paint the progress indicator. (`await null` only
///    yields a microtask and never gives up a frame.)
///
/// Measured on the Dart VM at 1,000 rows: ~300 ms of layout, now spread
/// across yields, plus ~430 ms inside `save()`. That save cannot be broken up
/// — it is the one remaining blocking step, and the reason
/// [ReportExportService.pdfRowLimit] exists. Disabling PDF compression to
/// speed it up was measured and rejected: it made files 25x larger without
/// making save meaningfully faster.
///
/// Every page repeats the column headers, which a paginated report wants.
Future<Uint8List> _renderTablePdf({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  PdfPageFormat? pageFormat,
  double cellFontSize = 7,
  double headerFontSize = 8,
  ExportProgress? onProgress,
}) async {
  final format = pageFormat ?? PdfPageFormat.a4.landscape;
  final pdf = pw.Document();

  if (rows.isEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [_pdfTitle(title), _pdfEmpty()],
        ),
      ),
    );
    return pdf.save();
  }

  final widths = _pdfColumnWidths(headers, rows);
  final total = rows.length;

  for (var start = 0; start < total; start += _pdfChunkRows) {
    final end =
        start + _pdfChunkRows < total ? start + _pdfChunkRows : total;
    final slice = rows.sublist(start, end);
    final isFirstPage = start == 0;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        // Default is 20, past which MultiPage throws TooManyPagesException —
        // and only via an assert, so it fails in debug and silently
        // paginates in release. A chunk is about one page, but a tall row
        // can spill, so leave headroom.
        maxPages: 1000,
        build: (pw.Context context) => [
          if (isFirstPage) _pdfTitle(title),
          _pdfTable(
            headers: headers,
            rows: slice,
            widths: widths,
            cellFontSize: cellFontSize,
            headerFontSize: headerFontSize,
          ),
        ],
      ),
    );
    onProgress?.call(end, total);
    await Future<void>.delayed(Duration.zero);
  }

  return pdf.save();
}

// ---------- Gate Entry ----------

_SheetData _buildGateEntryExcelRows(List<GateEntryReportItem> data) {
  const sheetName = 'Sheet1';
  final headers = <String>[
    'Gate Entry No',
    'Invoice/Challan Number',
    'Gate In Date',
    'Gate In Time',
    'Gate Out Time',
    'Turnaround Time',
    'Vendor',
    'Vendor Code',
    'PO Number',
    'Vehicle No',
    'LR Number',
    'Number Boxes (qty)',
    'Material',
  ];

  final rows = <List<Object?>>[];
  for (final item in data) {
    rows.add([
      item.gateEntryNo,
      item.challanNo,
      _formatDate(item.date),
      _formatTime(item.date),
      _formatTime(item.gateOutDate),
      _formatTurnaroundTime(item.date, item.gateOutDate),
      item.vendor,
      item.vendorCode,
      item.poNumber,
      item.vehicleNo,
      item.lrNo,
      item.qty,
      item.material,
    ]);
  }

  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildGateEntryPdfBytes(
  List<GateEntryReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'Gate Entry Register',
      pageFormat: PdfPageFormat.a4.landscape,
      headers: const [
        'Gate Entry No',
        'Invoice/Challan',
        'Gate In Date',
        'Gate In Time',
        'Gate Out Time',
        'Turnaround',
        'Vendor',
        'Vendor Code',
        'PO Number',
        'Vehicle No',
        'LR Number',
        'Qty',
        'Material',
      ],
      rows: data
          .map((item) => [
                item.gateEntryNo,
                item.challanNo,
                _formatDate(item.date),
                _formatTime(item.date),
                _formatTime(item.gateOutDate),
                _formatTurnaroundTime(item.date, item.gateOutDate),
                item.vendor,
                item.vendorCode,
                item.poNumber,
                item.vehicleNo,
                item.lrNo,
                item.qty.toString(),
                item.material,
              ])
          .toList(),
      onProgress: onProgress,
    );

// ---------- GRN Reconciliation ----------

_SheetData _buildGrnReconExcelRows(List<GrnReconReportItem> data) {
  const sheetName = 'Sheet1';
  final headers = <String>[
    'Gate Entry No',
    'GRN No',
    'PO No',
    'Challan No',
    'Matched Status',
    'Qty Diff',
    'Vendor Name',
    'Reconciled At',
    'Sr No',
    'Remarks',
    'Duplicate Reference',
    'Dublicate',
    'Reference No',
    'Reference',
    'Document Date',
    'Quantity',
    'Material',
    'Material Document',
    'Posting Date',
    'Plant',
    'Material Description',
    'Movement Type',
    'Movement Type Text',
    'Supplier',
    'Purchase Order',
    'Document Header Text',
    'User Name',
    'Entry Date',
    'Time Of Entry',
    'Amount In Local Currency',
    'Qty In Opun',
    'Qty In Order Unit',
    'Local Time',
    'Local Date',
    'Shift',
    'Store Remarks',
    'Status',
    'Aging',
    'MDR',
    'Scanning Invoice Status',
    'Scanning Date',
    'Vendor',
    'Source Vendor Name',
    'Buyer Name',
    'Maker Checker',
  ];

  final rows = <List<Object?>>[];
  for (final item in data) {
    rows.add([
      item.gateEntryNo ?? '',
      item.grnNo ?? '',
      item.poNumber ?? '',
      item.challanNo ?? '',
      item.matchedStatus ?? '',
      item.quantityDiff?.toString() ?? '',
      item.vendorName ?? '',
      item.reconciledAt ?? '',
      item.srNo ?? '',
      item.remarks ?? '',
      item.duplicateReference ?? '',
      item.dublicate ?? '',
      item.referenceNo ?? '',
      item.reference ?? '',
      item.documentDate ?? '',
      item.quantity ?? '',
      item.material ?? '',
      item.materialDocument ?? '',
      item.postingDate ?? '',
      item.plant ?? '',
      item.materialDescription ?? '',
      item.movementType ?? '',
      item.movementTypeText ?? '',
      item.supplier ?? '',
      item.purchaseOrder ?? '',
      item.documentHeaderText ?? '',
      item.userName ?? '',
      item.entryDate ?? '',
      item.timeOfEntry ?? '',
      item.amountInLocalCurrency ?? '',
      item.qtyInOpun ?? '',
      item.qtyInOrderUnit ?? '',
      item.localTime ?? '',
      item.localDate ?? '',
      item.shift ?? '',
      item.storeRemarks ?? '',
      item.status ?? '',
      item.aging ?? '',
      item.mdr ?? '',
      item.scanningInvoiceStatus ?? '',
      item.scanningDate ?? '',
      item.vendor ?? '',
      item.sourceVendorName ?? '',
      item.buyerName ?? '',
      item.makerChecker ?? '',
    ]);
  }

  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildGrnReconPdfBytes(
  List<GrnReconReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'GRN Reconciliation Report',
      pageFormat: PdfPageFormat.a4.landscape,
      headers: const [
        'Gate Entry',
        'GRN',
        'PO',
        'Challan',
        'Match Status',
        'Qty Diff',
        'Vendor',
        'Reconciled At',
        'Material',
        'MDR',
        'Remarks',
      ],
      rows: data
          .map((item) => [
                item.gateEntryNo ?? '',
                item.grnNo ?? '',
                item.poNumber ?? '',
                item.challanNo ?? '',
                item.matchedStatus ?? '',
                item.quantityDiff?.toString() ?? '',
                item.vendorName ?? item.vendor ?? '',
                item.reconciledAt ?? '',
                item.material ?? item.materialDescription ?? '',
                item.mdr ?? '',
                item.remarks ?? '',
              ])
          .toList(),
      cellFontSize: 7,
      headerFontSize: 8,
      onProgress: onProgress,
    );

// ---------- Pending GRN ----------

_SheetData _buildPendingGrnExcelRows(List<PendingGrnReportItem> data) {
  const sheetName = 'Sheet1';
  final headers = <String>[
    'Gate Entry No',
    'PO Number',
    'Vendor',
    'Material',
    'Days Pending',
  ];
  final rows = <List<Object?>>[];
  for (final item in data) {
    rows.add([
      item.gateEntryNo,
      item.poNumber,
      item.vendor,
      item.material,
      item.daysPending,
    ]);
  }
  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildPendingGrnPdfBytes(
  List<PendingGrnReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'Pending GRN Report',
      pageFormat: PdfPageFormat.a4,
      headers: const [
        'Entry No',
        'PO',
        'Vendor',
        'Material',
        'Days Pending',
      ],
      rows: data
          .map((item) => [
                item.gateEntryNo,
                item.poNumber,
                item.vendor,
                item.material,
                item.daysPending.toString(),
              ])
          .toList(),
      cellFontSize: 9,
      headerFontSize: 10,
      onProgress: onProgress,
    );

// ---------- Audit Trail ----------

_SheetData _buildAuditTrailExcelRows(List<AuditTrailReportItem> data) {
  const sheetName = 'Sheet1';
  final headers = <String>[
    'Date',
    'User',
    'Action',
    'Entity',
    'Changes',
  ];
  final rows = <List<Object?>>[];
  for (final item in data) {
    rows.add([
      item.date.toIso8601String(),
      item.user,
      item.action,
      item.entity,
      item.changes,
    ]);
  }
  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildAuditTrailPdfBytes(
  List<AuditTrailReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'Audit Trail Report',
      pageFormat: PdfPageFormat.a4.landscape,
      headers: const ['Date', 'User', 'Action', 'Entity', 'Changes'],
      rows: data
          .map((item) => [
                item.date.toString().substring(0, 19),
                item.user,
                item.action,
                item.entity,
                item.changes,
              ])
          .toList(),
      cellFontSize: 8,
      headerFontSize: 9,
      onProgress: onProgress,
    );

// ---------- Exception Report ----------

_SheetData _buildExceptionExcelRows(List<ExceptionReportItem> data) {
  const sheetName = 'Sheet1';
  final headers = <String>[
    'Gate Entry No',
    'Invoice No',
    'Part No',
    'Qty',
    'Vendor Name',
    'Vendor Code',
    'PO Number',
    'Status',
    'Description',
    'Created At',
  ];
  final rows = <List<Object?>>[];
  for (final item in data) {
    rows.add([
      item.gateEntryNo,
      item.invoiceNo,
      item.partNo,
      item.qty,
      item.vendorName,
      item.vendorCode,
      item.poNumber,
      item.status,
      item.description,
      '${_formatDate(item.createdAt)} ${_formatTime(item.createdAt)}'.trim(),
    ]);
  }
  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildExceptionPdfBytes(
  List<ExceptionReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'Exception Report',
      pageFormat: PdfPageFormat.a4.landscape,
      headers: const [
        'Gate Entry No',
        'Invoice No',
        'Part No',
        'Qty',
        'Vendor Name',
        'Vendor Code',
        'PO',
        'Status',
        'Description',
        'Created',
      ],
      rows: data
          .map((item) => [
                item.gateEntryNo,
                item.invoiceNo,
                item.partNo,
                item.qty.toString(),
                item.vendorName,
                item.vendorCode,
                item.poNumber,
                item.status,
                item.description,
                '${_formatDate(item.createdAt)} ${_formatTime(item.createdAt)}'
                    .trim(),
              ])
          .toList(),
      cellFontSize: 7,
      headerFontSize: 8,
      onProgress: onProgress,
    );

// ---------- Vehicle TAT ----------
//
// The KB Cytiva warehouse workbook uses columns:
//   DATE, SHIFT, VENDOR NAME, VEHICLE NO, Gate In, Schedule OK,
//   Dock In, Dock Out, DIDO, Remark1, Remark2, Remark3
// with derivations:
//   Remark1 = "With TAT"  if DIDO < 1h else "Out of TAT"
//   Remark2 = "Vehicle reported after 8:00 PM" if Gate In outside 06:00-20:00
//
// The backend does not yet expose Dock In / Dock Out per vehicle, so this
// report derives shift + after-hours flag from the Gate In timestamp, and
// uses Gate In → Gate Out as the TAT metric ("Gate TAT"). When the backend
// adds dock timestamps, wire them here and rename the columns.

String _shiftForGateIn(DateTime? gateIn) {
  if (gateIn == null) return '';
  final hour = gateIn.toLocal().hour;
  if (hour >= 6 && hour < 14) return '1ST';
  if (hour >= 14 && hour < 22) return '2ND';
  return '3RD';
}

String _tatBucket(Duration? tat) {
  if (tat == null) return '';
  return tat.inMinutes < 60 ? 'With TAT' : 'Out of TAT';
}

String _afterHoursFlag(DateTime? gateIn) {
  if (gateIn == null) return '';
  final hour = gateIn.toLocal().hour;
  return (hour >= 20 || hour < 6) ? 'Vehicle reported after 8:00 PM' : '';
}

Duration? _tatDuration(DateTime? gateIn, DateTime? gateOut) {
  if (gateIn == null || gateOut == null) return null;
  final diff = gateOut.difference(gateIn);
  return diff.isNegative ? null : diff;
}

String _formatDuration(Duration? d) {
  if (d == null) return '-';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m}m';
}

_SheetData _buildVehicleTatExcelRows(List<GateEntryReportItem> data) {
  const sheetName = 'Inward TAT';
  final headers = <String>[
    'DATE',
    'SHIFT',
    'VENDOR NAME',
    'VEHICLE NO',
    'Gate In Time',
    'Gate Out Time',
    'TAT (Gate In → Gate Out)',
    'Remark 1',
    'Remark 2',
  ];

  final rows = <List<Object?>>[];
  for (final item in data) {
    final tat = _tatDuration(item.date, item.gateOutDate);
    rows.add([
      _formatDate(item.date),
      _shiftForGateIn(item.date),
      item.vendor,
      item.vehicleNo,
      _formatTime(item.date),
      _formatTime(item.gateOutDate),
      _formatDuration(tat),
      _tatBucket(tat),
      _afterHoursFlag(item.date),
    ]);
  }

  return (sheetName: sheetName, headers: headers, rows: rows);
}

Future<Uint8List> _buildVehicleTatPdfBytes(
  List<GateEntryReportItem> data, {
  ExportProgress? onProgress,
}) =>
    _renderTablePdf(
      title: 'Vehicle TAT Report (Inward)',
      pageFormat: PdfPageFormat.a4.landscape,
      headers: const [
        'Date',
        'Shift',
        'Vendor',
        'Vehicle No',
        'Gate In',
        'Gate Out',
        'TAT',
        'Remark 1',
        'Remark 2',
      ],
      rows: data.map((item) {
        final tat = _tatDuration(item.date, item.gateOutDate);
        return [
          _formatDate(item.date),
          _shiftForGateIn(item.date),
          item.vendor,
          item.vehicleNo,
          _formatTime(item.date),
          _formatTime(item.gateOutDate),
          _formatDuration(tat),
          _tatBucket(tat),
          _afterHoursFlag(item.date),
        ];
      }).toList(),
      cellFontSize: 8,
      headerFontSize: 9,
      onProgress: onProgress,
    );
