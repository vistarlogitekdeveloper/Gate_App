import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/gate_entry.dart';
import '../models/gate_entry_item.dart';

class GatePassItemInfo {
  const GatePassItemInfo({
    required this.materialCode,
    required this.poNumber,
    required this.challanQty,
    required this.uom,
    this.challanNo,
  });

  final String materialCode;
  final String poNumber;
  final num challanQty;
  final String uom;
  final String? challanNo;
}

class GatePassPdfService {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  Future<void> printGatePass(GateEntry entry) {
    return printGatePassFromFields(
      gatePassNo: _gatePassNoFor(entry),
      isInward: entry.gateMovement == GateMovement.inMovement,
      entryDate: entry.gateTimestamp,
      vendorName: entry.vendorName,
      challanNo: entry.challanNo,
      vehicleNo: entry.vehicleNo,
      lrNumber: entry.lrNumber,
      countSheetNo: entry.countSheetNo,
      items: entry.items.map(_fromGateEntryItem).toList(),
    );
  }

  Future<void> shareGatePass(GateEntry entry) {
    return shareGatePassFromFields(
      gatePassNo: _gatePassNoFor(entry),
      isInward: entry.gateMovement == GateMovement.inMovement,
      entryDate: entry.gateTimestamp,
      vendorName: entry.vendorName,
      challanNo: entry.challanNo,
      vehicleNo: entry.vehicleNo,
      lrNumber: entry.lrNumber,
      countSheetNo: entry.countSheetNo,
      items: entry.items.map(_fromGateEntryItem).toList(),
    );
  }

  Future<void> printGatePassFromFields({
    required String gatePassNo,
    required bool isInward,
    required DateTime? entryDate,
    required String vendorName,
    required String challanNo,
    required String vehicleNo,
    required String lrNumber,
    required List<GatePassItemInfo> items,
    String? countSheetNo,
  }) async {
    final doc = _buildDocument(
      gatePassNo: gatePassNo,
      isInward: isInward,
      entryDate: entryDate,
      vendorName: vendorName,
      challanNo: challanNo,
      vehicleNo: vehicleNo,
      lrNumber: lrNumber,
      items: items,
      countSheetNo: countSheetNo,
    );
    await Printing.layoutPdf(
      name: _fileName(gatePassNo, isInward),
      onLayout: (PdfPageFormat format) async {
        await Future.delayed(Duration.zero);
        return doc.save();
      },
    );
  }

  Future<void> shareGatePassFromFields({
    required String gatePassNo,
    required bool isInward,
    required DateTime? entryDate,
    required String vendorName,
    required String challanNo,
    required String vehicleNo,
    required String lrNumber,
    required List<GatePassItemInfo> items,
    String? countSheetNo,
  }) async {
    final doc = _buildDocument(
      gatePassNo: gatePassNo,
      isInward: isInward,
      entryDate: entryDate,
      vendorName: vendorName,
      challanNo: challanNo,
      vehicleNo: vehicleNo,
      lrNumber: lrNumber,
      items: items,
      countSheetNo: countSheetNo,
    );
    await Future.delayed(Duration.zero);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(gatePassNo, isInward),
    );
  }

  String _gatePassNoFor(GateEntry entry) {
    final no = (entry.gateEntryNo ?? '').trim();
    return no.isNotEmpty ? no : entry.id;
  }

  GatePassItemInfo _fromGateEntryItem(GateEntryItem item) {
    return GatePassItemInfo(
      materialCode: item.materialCode,
      poNumber: item.poNumber,
      challanQty: item.challanQty,
      uom: item.uom,
      challanNo: item.challanNo,
    );
  }

  /// Builds the "D.C. / Inv. No." display line. If items carry per-line
  /// challan numbers, surface every unique value (joined by ", "). Otherwise
  /// fall back to the single [challanNo] argument.
  String _buildChallanDisplay({
    required String challanNo,
    required List<GatePassItemInfo> items,
  }) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final item in items) {
      final value = (item.challanNo ?? '').trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) ordered.add(value);
    }
    if (ordered.isNotEmpty) return ordered.join(', ');
    return challanNo.trim();
  }

  pw.Document _buildDocument({
    required String gatePassNo,
    required bool isInward,
    required DateTime? entryDate,
    required String vendorName,
    required String challanNo,
    required String vehicleNo,
    required String lrNumber,
    required List<GatePassItemInfo> items,
    String? countSheetNo,
  }) {
    final doc = pw.Document();

    final dateText = entryDate != null
        ? _dateFormat.format(entryDate.toLocal())
        : _dateFormat.format(DateTime.now());
    final descriptionLines = _buildDescriptionLines(items);
    final challanLine = _buildChallanDisplay(
      challanNo: challanNo,
      items: items,
    );
    final vehicleAndLr = _buildVehicleAndLr(vehicleNo, lrNumber);

    doc.addPage(
      pw.Page(
        // A5 landscape (210 x 148.5 mm) = exactly half of A4 portrait.
        // Gate pass content fills this page edge-to-edge with no wasted space.
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return _gatePassBlock(
            isInward: isInward,
            gatePassNo: gatePassNo,
            date: dateText,
            countSheetNo: countSheetNo,
            vendorName: vendorName,
            challanLine: challanLine,
            descriptionLines: descriptionLines,
            vehicleAndLr: vehicleAndLr,
          );
        },
      ),
    );

    return doc;
  }

  pw.Widget _gatePassBlock({
    required bool isInward,
    required String gatePassNo,
    required String date,
    String? countSheetNo,
    required String vendorName,
    required String challanLine,
    required List<String> descriptionLines,
    required String vehicleAndLr,
  }) {
    final title = isInward ? 'GATE PASS INWARD' : 'GATE PASS OUTWARD';
    final footerLabel = isInward ? 'Security' : 'Authorised Signatory';
    final vehicleLabel =
        isInward ? 'Vehicle & LR no :- ' : 'Vehicle no/LR No :- ';

    return pw.SizedBox.expand(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _titleBar(title),
            _gatePassNoRow(
                gatePassNo: gatePassNo, date: date, countSheetNo: countSheetNo),
            _addressAndMsRow(vendorName),
            _labeledBlock(
              label: 'D.C. / Inv. No.',
              content: challanLine,
              minHeight: 40,
            ),
            pw.Expanded(
              child: _labeledBlock(
                label: 'Description of Goods :-',
                content: descriptionLines.join('\n'),
                minHeight: 0,
                expand: true,
              ),
            ),
            _footerRow(
              vehicleLabel: vehicleLabel,
              vehicleAndLr: vehicleAndLr,
              footerLabel: footerLabel,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _titleBar(String title) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _gatePassNoRow({
    required String gatePassNo,
    required String date,
    String? countSheetNo,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(right: pw.BorderSide(width: 1)),
                ),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Gate Pass No :- ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(text: gatePassNo),
                    ],
                  ),
                ),
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Date :- ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(text: date),
                      if (countSheetNo != null && countSheetNo.isNotEmpty) ...[
                        pw.TextSpan(
                          text: '     Count Sheet :- ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.TextSpan(text: countSheetNo),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _addressAndMsRow(String vendorName) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(right: pw.BorderSide(width: 1)),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Schwing Stetter India Pvt Ltd',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('C/o Bhoir Dredging Co Pvt Ltd,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Bhoir Compound ,CS-20, Ghodbunder,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(' Behind Velkar Petrol Pump,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Thane, Village-Versova,',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('MAHARSHTRA - 401104.',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('M/S :-',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 6),
                    _underlinedLine(vendorName),
                    pw.SizedBox(height: 10),
                    _underlinedLine(''),
                    pw.SizedBox(height: 10),
                    _underlinedLine(''),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _underlinedLine(String text) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.7)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _labeledBlock({
    required String label,
    required String content,
    required double minHeight,
    bool expand = false,
  }) {
    return pw.Container(
      width: double.infinity,
      height: expand ? double.infinity : null,
      constraints:
          expand ? null : pw.BoxConstraints(minHeight: minHeight),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          if (content.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(content, style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  pw.Widget _footerRow({
    required String vehicleLabel,
    required String vehicleAndLr,
    required String footerLabel,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: vehicleLabel,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: vehicleAndLr),
                ],
              ),
            ),
          ),
          pw.Text(
            footerLabel,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<String> _buildDescriptionLines(List<GatePassItemInfo> items) {
    if (items.isEmpty) return const [];
    return items.map((item) {
      final parts = <String>[];
      if (item.materialCode.trim().isNotEmpty) {
        parts.add(item.materialCode.trim());
      }
      parts.add('Qty: ${item.challanQty} ${item.uom}'.trim());
      if (item.poNumber.trim().isNotEmpty) {
        parts.add('PO: ${item.poNumber.trim()}');
      }
      return parts.join('  |  ');
    }).toList();
  }

  String _buildVehicleAndLr(String vehicleNo, String lrNumber) {
    final vehicle = vehicleNo.trim();
    final lr = lrNumber.trim();
    if (vehicle.isEmpty && lr.isEmpty) return '';
    if (vehicle.isEmpty) return lr;
    if (lr.isEmpty) return vehicle;
    return '$vehicle / $lr';
  }

  String _fileName(String gatePassNo, bool isInward) {
    final ref = gatePassNo.trim().isEmpty ? 'gate_pass' : gatePassNo.trim();
    final safe = ref.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final suffix = isInward ? 'inward' : 'outward';
    return 'gate_pass_${suffix}_$safe.pdf';
  }
}

final gatePassPdfService = GatePassPdfService();
