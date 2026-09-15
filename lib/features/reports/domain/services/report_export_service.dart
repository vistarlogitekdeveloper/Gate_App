import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exception_report_item.dart';
import '../models/report_models.dart';
import 'export_file_helper.dart';

class ReportExportService {
  final ExportFileHelper _fileHelper = getExportFileHelper();

  Future<void> exportGateEntryRegisterToExcel(
      List<GateEntryReportItem> data) async {
    final bytes = await compute(_buildGateEntryExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'GateEntryRegister.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportGateEntryRegisterToPdf(
      List<GateEntryReportItem> data) async {
    final bytes = await compute(_buildGateEntryPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'GateEntryRegister.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportGrnReconReportToExcel(
      List<GrnReconReportItem> data) async {
    final bytes = await compute(_buildGrnReconExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'GRN_Reconciliation.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportGrnReconReportToPdf(List<GrnReconReportItem> data) async {
    final bytes = await compute(_buildGrnReconPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'GRN_Reconciliation.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportPendingGrnReportToExcel(
      List<PendingGrnReportItem> data) async {
    final bytes = await compute(_buildPendingGrnExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Pending_GRN.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportPendingGrnReportToPdf(
      List<PendingGrnReportItem> data) async {
    final bytes = await compute(_buildPendingGrnPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Pending_GRN.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportAuditTrailReportToExcel(
      List<AuditTrailReportItem> data) async {
    final bytes = await compute(_buildAuditTrailExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Audit_Trail.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportAuditTrailReportToPdf(
      List<AuditTrailReportItem> data) async {
    final bytes = await compute(_buildAuditTrailPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Audit_Trail.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportExceptionReportToExcel(
      List<ExceptionReportItem> data) async {
    final bytes = await compute(_buildExceptionExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Exception_Report.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportExceptionReportToPdf(
      List<ExceptionReportItem> data) async {
    final bytes = await compute(_buildExceptionPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Exception_Report.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  // Vehicle TAT is derived on the client from the gate entry register (Gate
  // In = entry.date, Gate Out = entry.gateOutDate). The Excel format shared
  // by the warehouse team uses Dock In / Dock Out, which the backend does not
  // yet expose — see backend_api_spec.md for the pending fields. For now we
  // report Gate-TAT (Gate In → Gate Out) with the same shift / after-hours /
  // "With TAT" / "Out of TAT" derivations as the shared workbook.
  Future<void> exportVehicleTatReportToExcel(
      List<GateEntryReportItem> data) async {
    final bytes = await compute(_buildVehicleTatExcelBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Vehicle_TAT_Report.xlsx',
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportVehicleTatReportToPdf(
      List<GateEntryReportItem> data) async {
    final bytes = await compute(_buildVehicleTatPdfBytes, data);
    await _fileHelper.saveAndShare(
      fileName: 'Vehicle_TAT_Report.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }
}

// ---------------------------------------------------------------------------
// Background-isolate helpers
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

pw.Widget _pdfTable({
  required List<String> headers,
  required List<List<String>> rows,
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
    headers: headers,
    data: rows,
  );
}

// ---------- Gate Entry ----------

List<int> _buildGateEntryExcelBytes(List<GateEntryReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Sheet1'];

  sheet.appendRow([
    xl.TextCellValue('Gate Entry No'),
    xl.TextCellValue('Invoice/Challan Number'),
    xl.TextCellValue('Gate In Date'),
    xl.TextCellValue('Gate In Time'),
    xl.TextCellValue('Gate Out Time'),
    xl.TextCellValue('Turnaround Time'),
    xl.TextCellValue('Vendor'),
    xl.TextCellValue('Vendor Code'),
    xl.TextCellValue('PO Number'),
    xl.TextCellValue('Vehicle No'),
    xl.TextCellValue('LR Number'),
    xl.TextCellValue('Number Boxes (qty)'),
    xl.TextCellValue('Material'),
  ]);

  for (final item in data) {
    sheet.appendRow([
      xl.TextCellValue(item.gateEntryNo),
      xl.TextCellValue(item.challanNo),
      xl.TextCellValue(_formatDate(item.date)),
      xl.TextCellValue(_formatTime(item.date)),
      xl.TextCellValue(_formatTime(item.gateOutDate)),
      xl.TextCellValue(_formatTurnaroundTime(item.date, item.gateOutDate)),
      xl.TextCellValue(item.vendor),
      xl.TextCellValue(item.vendorCode),
      xl.TextCellValue(item.poNumber),
      xl.TextCellValue(item.vehicleNo),
      xl.TextCellValue(item.lrNo),
      xl.IntCellValue(item.qty),
      xl.TextCellValue(item.material),
    ]);
  }

  return excel.encode()!;
}

Future<Uint8List> _buildGateEntryPdfBytes(
    List<GateEntryReportItem> data) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('Gate Entry Register'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );

  return pdf.save();
}

// ---------- GRN Reconciliation ----------

List<int> _buildGrnReconExcelBytes(List<GrnReconReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Sheet1'];

  sheet.appendRow([
    xl.TextCellValue('Gate Entry No'),
    xl.TextCellValue('GRN No'),
    xl.TextCellValue('PO No'),
    xl.TextCellValue('Challan No'),
    xl.TextCellValue('Matched Status'),
    xl.TextCellValue('Qty Diff'),
    xl.TextCellValue('Vendor Name'),
    xl.TextCellValue('Reconciled At'),
    xl.TextCellValue('Sr No'),
    xl.TextCellValue('Remarks'),
    xl.TextCellValue('Duplicate Reference'),
    xl.TextCellValue('Dublicate'),
    xl.TextCellValue('Reference No'),
    xl.TextCellValue('Reference'),
    xl.TextCellValue('Document Date'),
    xl.TextCellValue('Quantity'),
    xl.TextCellValue('Material'),
    xl.TextCellValue('Material Document'),
    xl.TextCellValue('Posting Date'),
    xl.TextCellValue('Plant'),
    xl.TextCellValue('Material Description'),
    xl.TextCellValue('Movement Type'),
    xl.TextCellValue('Movement Type Text'),
    xl.TextCellValue('Supplier'),
    xl.TextCellValue('Purchase Order'),
    xl.TextCellValue('Document Header Text'),
    xl.TextCellValue('User Name'),
    xl.TextCellValue('Entry Date'),
    xl.TextCellValue('Time Of Entry'),
    xl.TextCellValue('Amount In Local Currency'),
    xl.TextCellValue('Qty In Opun'),
    xl.TextCellValue('Qty In Order Unit'),
    xl.TextCellValue('Local Time'),
    xl.TextCellValue('Local Date'),
    xl.TextCellValue('Shift'),
    xl.TextCellValue('Store Remarks'),
    xl.TextCellValue('Status'),
    xl.TextCellValue('Aging'),
    xl.TextCellValue('MDR'),
    xl.TextCellValue('Scanning Invoice Status'),
    xl.TextCellValue('Scanning Date'),
    xl.TextCellValue('Vendor'),
    xl.TextCellValue('Source Vendor Name'),
    xl.TextCellValue('Buyer Name'),
    xl.TextCellValue('Maker Checker'),
  ]);

  for (final item in data) {
    sheet.appendRow([
      xl.TextCellValue(item.gateEntryNo ?? ''),
      xl.TextCellValue(item.grnNo ?? ''),
      xl.TextCellValue(item.poNumber ?? ''),
      xl.TextCellValue(item.challanNo ?? ''),
      xl.TextCellValue(item.matchedStatus ?? ''),
      xl.TextCellValue(item.quantityDiff?.toString() ?? ''),
      xl.TextCellValue(item.vendorName ?? ''),
      xl.TextCellValue(item.reconciledAt ?? ''),
      xl.TextCellValue(item.srNo ?? ''),
      xl.TextCellValue(item.remarks ?? ''),
      xl.TextCellValue(item.duplicateReference ?? ''),
      xl.TextCellValue(item.dublicate ?? ''),
      xl.TextCellValue(item.referenceNo ?? ''),
      xl.TextCellValue(item.reference ?? ''),
      xl.TextCellValue(item.documentDate ?? ''),
      xl.TextCellValue(item.quantity ?? ''),
      xl.TextCellValue(item.material ?? ''),
      xl.TextCellValue(item.materialDocument ?? ''),
      xl.TextCellValue(item.postingDate ?? ''),
      xl.TextCellValue(item.plant ?? ''),
      xl.TextCellValue(item.materialDescription ?? ''),
      xl.TextCellValue(item.movementType ?? ''),
      xl.TextCellValue(item.movementTypeText ?? ''),
      xl.TextCellValue(item.supplier ?? ''),
      xl.TextCellValue(item.purchaseOrder ?? ''),
      xl.TextCellValue(item.documentHeaderText ?? ''),
      xl.TextCellValue(item.userName ?? ''),
      xl.TextCellValue(item.entryDate ?? ''),
      xl.TextCellValue(item.timeOfEntry ?? ''),
      xl.TextCellValue(item.amountInLocalCurrency ?? ''),
      xl.TextCellValue(item.qtyInOpun ?? ''),
      xl.TextCellValue(item.qtyInOrderUnit ?? ''),
      xl.TextCellValue(item.localTime ?? ''),
      xl.TextCellValue(item.localDate ?? ''),
      xl.TextCellValue(item.shift ?? ''),
      xl.TextCellValue(item.storeRemarks ?? ''),
      xl.TextCellValue(item.status ?? ''),
      xl.TextCellValue(item.aging ?? ''),
      xl.TextCellValue(item.mdr ?? ''),
      xl.TextCellValue(item.scanningInvoiceStatus ?? ''),
      xl.TextCellValue(item.scanningDate ?? ''),
      xl.TextCellValue(item.vendor ?? ''),
      xl.TextCellValue(item.sourceVendorName ?? ''),
      xl.TextCellValue(item.buyerName ?? ''),
      xl.TextCellValue(item.makerChecker ?? ''),
    ]);
  }

  return excel.encode()!;
}

Future<Uint8List> _buildGrnReconPdfBytes(
    List<GrnReconReportItem> data) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('GRN Reconciliation Report'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );

  return pdf.save();
}

// ---------- Pending GRN ----------

List<int> _buildPendingGrnExcelBytes(List<PendingGrnReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([
    xl.TextCellValue('Gate Entry No'),
    xl.TextCellValue('PO Number'),
    xl.TextCellValue('Vendor'),
    xl.TextCellValue('Material'),
    xl.TextCellValue('Days Pending'),
  ]);
  for (final item in data) {
    sheet.appendRow([
      xl.TextCellValue(item.gateEntryNo),
      xl.TextCellValue(item.poNumber),
      xl.TextCellValue(item.vendor),
      xl.TextCellValue(item.material),
      xl.IntCellValue(item.daysPending),
    ]);
  }
  return excel.encode()!;
}

Future<Uint8List> _buildPendingGrnPdfBytes(
    List<PendingGrnReportItem> data) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('Pending GRN Report'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );
  return pdf.save();
}

// ---------- Audit Trail ----------

List<int> _buildAuditTrailExcelBytes(List<AuditTrailReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([
    xl.TextCellValue('Date'),
    xl.TextCellValue('User'),
    xl.TextCellValue('Action'),
    xl.TextCellValue('Entity'),
    xl.TextCellValue('Changes'),
  ]);
  for (final item in data) {
    sheet.appendRow([
      xl.TextCellValue(item.date.toIso8601String()),
      xl.TextCellValue(item.user),
      xl.TextCellValue(item.action),
      xl.TextCellValue(item.entity),
      xl.TextCellValue(item.changes),
    ]);
  }
  return excel.encode()!;
}

Future<Uint8List> _buildAuditTrailPdfBytes(
    List<AuditTrailReportItem> data) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('Audit Trail Report'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );
  return pdf.save();
}

// ---------- Exception Report ----------

List<int> _buildExceptionExcelBytes(List<ExceptionReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([
    xl.TextCellValue('Gate Entry No'),
    xl.TextCellValue('Invoice No'),
    xl.TextCellValue('Part No'),
    xl.TextCellValue('Qty'),
    xl.TextCellValue('Vendor Name'),
    xl.TextCellValue('Vendor Code'),
    xl.TextCellValue('PO Number'),
    xl.TextCellValue('Status'),
    xl.TextCellValue('Description'),
    xl.TextCellValue('Created At'),
  ]);
  for (final item in data) {
    sheet.appendRow([
      xl.TextCellValue(item.gateEntryNo),
      xl.TextCellValue(item.invoiceNo),
      xl.TextCellValue(item.partNo),
      xl.IntCellValue(item.qty),
      xl.TextCellValue(item.vendorName),
      xl.TextCellValue(item.vendorCode),
      xl.TextCellValue(item.poNumber),
      xl.TextCellValue(item.status),
      xl.TextCellValue(item.description),
      xl.TextCellValue(
          '${_formatDate(item.createdAt)} ${_formatTime(item.createdAt)}'.trim()),
    ]);
  }
  return excel.encode()!;
}

Future<Uint8List> _buildExceptionPdfBytes(
    List<ExceptionReportItem> data) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('Exception Report'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );
  return pdf.save();
}

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

List<int> _buildVehicleTatExcelBytes(List<GateEntryReportItem> data) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Inward TAT'];

  sheet.appendRow([
    xl.TextCellValue('DATE'),
    xl.TextCellValue('SHIFT'),
    xl.TextCellValue('VENDOR NAME'),
    xl.TextCellValue('VEHICLE NO'),
    xl.TextCellValue('Gate In Time'),
    xl.TextCellValue('Gate Out Time'),
    xl.TextCellValue('TAT (Gate In → Gate Out)'),
    xl.TextCellValue('Remark 1'),
    xl.TextCellValue('Remark 2'),
  ]);

  for (final item in data) {
    final tat = _tatDuration(item.date, item.gateOutDate);
    sheet.appendRow([
      xl.TextCellValue(_formatDate(item.date)),
      xl.TextCellValue(_shiftForGateIn(item.date)),
      xl.TextCellValue(item.vendor),
      xl.TextCellValue(item.vehicleNo),
      xl.TextCellValue(_formatTime(item.date)),
      xl.TextCellValue(_formatTime(item.gateOutDate)),
      xl.TextCellValue(_formatDuration(tat)),
      xl.TextCellValue(_tatBucket(tat)),
      xl.TextCellValue(_afterHoursFlag(item.date)),
    ]);
  }

  return excel.encode()!;
}

Future<Uint8List> _buildVehicleTatPdfBytes(
    List<GateEntryReportItem> data) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        _pdfTitle('Vehicle TAT Report (Inward)'),
        if (data.isEmpty)
          _pdfEmpty()
        else
          _pdfTable(
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
          ),
      ],
    ),
  );
  return pdf.save();
}
