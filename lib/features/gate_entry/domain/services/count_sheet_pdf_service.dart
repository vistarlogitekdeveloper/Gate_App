import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/gate_entry.dart';

/// The printed count sheet: the client's "Receipt And Put Away Sheet".
///
/// One sheet per count sheet number (one vehicle, all of its invoices). The
/// system fills what it knows -- count sheet no., vehicle, vendor, gate in,
/// gate entry / invoice / item / quantity per line -- and leaves ruled blanks
/// for what the warehouse writes by hand: receiving, put away, GRN, location,
/// boxes, pallets and storage type, and the signatures.
///
/// A4 landscape. A long sheet continues on further pages with the column
/// header and a compact page header repeated; the details, totals and
/// signatures appear once.
class CountSheetPdfService {
  CountSheetPdfService._();

  static const _vistarLogo = 'assets/images/vistar_logo_print.png';
  static const _knorrBremseLogo = 'assets/images/client_knorr_bremse.png';

  // Vistar brand, print-safe: strong ink only for text, tints for fills.
  static const _brand = PdfColor.fromInt(0xFF7A1FB0);
  static const _brandPink = PdfColor.fromInt(0xFFE0218A);
  static const _ink = PdfColor.fromInt(0xFF1F1A24);
  static const _muted = PdfColor.fromInt(0xFF6B6474);
  static const _rule = PdfColor.fromInt(0xFFBDB6C4);
  static const _headFill = PdfColor.fromInt(0xFFF1E6F8);
  static const _zebra = PdfColor.fromInt(0xFFFAF7FC);
  static const _writeFill = PdfColor.fromInt(0xFFFFFFFF);

  static final _date = DateFormat('dd MMM yyyy');
  static final _time = DateFormat('hh:mm a');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _qty = NumberFormat('#,##0.###');

  /// Rows on the sheet are padded with numbered blanks up to this many, so
  /// there is always room to write in an extra line at the dock.
  static const _minRows = 10;

  /// The built-in Helvetica only covers Latin-1, and the app bundles no
  /// Unicode font. Data (vendor and user names typed anywhere) is mapped to
  /// it: typographic quotes and dashes to plain ones, anything else outside
  /// Latin-1 dropped -- never a broken glyph on the printed sheet.
  static String _safe(String? value) {
    if (value == null || value.isEmpty) return '';
    const map = {
      '‘': "'", '’': "'", '‚': "'", '“': '"', '”': '"',
      '–': '-', '—': '-', '…': '...', ' ': ' ', '•': '-',
    };
    final out = StringBuffer();
    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = map[ch];
      if (mapped != null) {
        out.write(mapped);
      } else if (rune >= 0x20 && rune <= 0xFF && !(rune >= 0x7F && rune < 0xA0)) {
        out.write(ch);
      }
    }
    return out.toString().trim();
  }

  static Future<pw.MemoryImage?> _asset(String? path) async {
    if (path == null) return null;
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null; // a missing logo must never stop the sheet printing
    }
  }

  /// Builds the PDF for [countSheetNo] from its gate entries.
  static Future<Uint8List> build({
    required String countSheetNo,
    required List<GateEntry> entries,
    required String orgCode,
    required String orgName,
    required String printedBy,
    DateTime? printedAt,
  }) async {
    final vistar = await _asset(_vistarLogo);
    // The sheet is Knorr-Bremse's Receipt And Put Away Sheet: it always
    // carries their logo. (It used to depend on the organisation's code or
    // name, which in production do not mention Knorr-Bremse.)
    final client = await _asset(_knorrBremseLogo);
    final at = (printedAt ?? DateTime.now()).toLocal();
    countSheetNo = _safe(countSheetNo);
    printedBy = _safe(printedBy);
    orgName = _safe(orgName);

    final sorted = [...entries]
      ..sort((a, b) => (a.gateEntryNo ?? '').compareTo(b.gateEntryNo ?? ''));
    final lines = <_Line>[];
    for (final e in sorted) {
      if (e.items.isEmpty) {
        lines.add(_Line(entry: e));
      } else {
        for (final item in e.items) {
          lines.add(_Line(
            entry: e,
            itemCode: _safe(item.materialCode),
            poNumber: _safe(item.poNumber),
            qty: item.challanQty,
            uom: _safe(item.uom),
          ));
        }
      }
    }
    final totalQty = lines.fold<num>(0, (sum, l) => sum + (l.qty ?? 0));
    final rowCount = lines.length < _minRows ? _minRows : lines.length;

    final first = sorted.isNotEmpty ? sorted.first : null;
    String distinct(Iterable<String> values) {
      final seen = <String>{};
      return values
          .map(_safe)
          .where((v) => v.isNotEmpty && seen.add(v.toUpperCase()))
          .join(', ');
    }

    final vehicle = distinct(sorted.map((e) => e.vehicleNo));
    final vendorCode = distinct(sorted.map((e) => e.vendorCode));
    final vendorName = distinct(sorted.map((e) => e.vendorName));
    final transporter = distinct(sorted.map((e) => e.transporterName));
    final lr = distinct(sorted.map((e) => e.lrNumber));
    final driver = distinct(sorted.map((e) => e.driverContactNo));
    final createdBy = distinct(sorted.map((e) => e.createdBy ?? ''));
    final gateIn = first?.gateTimestamp?.toLocal();
    final gateOut = sorted
        .map((e) => e.gateOutTimestamp)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a)
        ?.toLocal();
    final direction =
        first?.gateMovement == GateMovement.outMovement ? 'Gate Out' : 'Gate In';

    final clientName = client != null ? 'Knorr-Bremse' : orgName.trim();
    final doc = pw.Document(
      title: 'Count Sheet $countSheetNo',
      author: 'Vistar Logitek',
      creator: 'Vistar Gate Reco',
      subject: 'Receipt and Put Away Sheet',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 16),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ).copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 8.5, color: _ink)),
        header: (context) => context.pageNumber == 1
            ? _brandHeader(vistar: vistar, client: client, clientName: clientName)
            : _continuationHeader(countSheetNo: countSheetNo, vehicle: vehicle,
                vistar: vistar, page: context.pageNumber, pages: context.pagesCount),
        footer: (context) => _footer(
          countSheetNo: countSheetNo,
          printedBy: printedBy,
          printedAt: at,
          page: context.pageNumber,
          pages: context.pagesCount,
        ),
        build: (context) => [
          _detailsBand(
            countSheetNo: countSheetNo,
            direction: direction,
            gateIn: gateIn,
            gateOut: gateOut,
            vehicle: vehicle,
            vendorCode: vendorCode,
            vendorName: vendorName,
            transporter: transporter,
            lr: lr,
            driver: driver,
            invoiceCount: sorted.length,
          ),
          pw.SizedBox(height: 8),
          _linesTable(lines: lines, rowCount: rowCount),
          _totalsRow(
            invoiceCount: sorted.length,
            lineCount: lines.length,
            totalQty: totalQty,
          ),
          pw.SizedBox(height: 8),
          _signatures(gateSecurity: createdBy),
        ],
      ),
    );
    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _brandHeader({
    required pw.MemoryImage? vistar,
    required pw.MemoryImage? client,
    required String clientName,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 150,
              height: 44,
              child: vistar != null
                  ? pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(vistar, height: 44))
                  : pw.Text('VISTAR LOGITEK',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _brand)),
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    'RECEIPT AND PUT AWAY SHEET',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                      color: _ink,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    clientName.isEmpty
                        ? 'Vistar Logitek Pvt. Ltd.  |  Gate Count Sheet'
                        : 'Vistar Logitek Pvt. Ltd.  x  $clientName  |  Gate Count Sheet',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(
              width: 150,
              height: 44,
              child: client != null
                  ? pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(client, width: 150))
                  : pw.SizedBox(),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        // Brand rule: purple into pink.
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Container(height: 2.2, color: _brand)),
          pw.Expanded(flex: 2, child: pw.Container(height: 2.2, color: _brandPink)),
        ]),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _continuationHeader({
    required String countSheetNo,
    required String vehicle,
    required pw.MemoryImage? vistar,
    required int page,
    required int pages,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.2)),
      ),
      child: pw.Row(
        children: [
          if (vistar != null) pw.Image(vistar, height: 20),
          pw.SizedBox(width: 10),
          pw.Text('RECEIPT AND PUT AWAY SHEET  (continued)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Spacer(),
          pw.Text('Count Sheet ', style: const pw.TextStyle(color: _muted)),
          pw.Text(countSheetNo,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _brand)),
          if (vehicle.isNotEmpty) pw.Text('   Vehicle $vehicle', style: const pw.TextStyle(color: _muted)),
          pw.Text('   Page $page of $pages', style: const pw.TextStyle(color: _muted)),
        ],
      ),
    );
  }

  // ── Details: count sheet box | system details | handwritten fields ───────

  static pw.Widget _detailsBand({
    required String countSheetNo,
    required String direction,
    required DateTime? gateIn,
    required DateTime? gateOut,
    required String vehicle,
    required String vendorCode,
    required String vendorName,
    required String transporter,
    required String lr,
    required String driver,
    required int invoiceCount,
  }) {
    const dash = '-';
    final system = <(String, String)>[
      ('Vehicle No.', vehicle.isEmpty ? dash : vehicle),
      ('Vendor Code', vendorCode.isEmpty ? dash : vendorCode),
      ('Vendor Name', vendorName.isEmpty ? dash : vendorName),
      ('Transporter', transporter.isEmpty ? dash : transporter),
      ('LR No.', lr.isEmpty ? dash : lr),
      ('Driver Contact', driver.isEmpty ? dash : driver),
    ];
    final gate = <(String, String)>[
      ('Direction', direction),
      ('Gate In Date', gateIn == null ? dash : _date.format(gateIn)),
      ('Gate In Time', gateIn == null ? dash : _time.format(gateIn)),
      ('Gate Out', gateOut == null ? 'Inside' : _dateTime.format(gateOut)),
      ('Invoices', '$invoiceCount'),
    ];

    // A fixed height: inside a MultiPage a stretched Row has no height
    // limit, and all four boxes should line up anyway.
    return pw.SizedBox(
      height: 132,
      child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // The count sheet number, big, with a scannable barcode.
        pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: _headFill,
            border: pw.Border.all(color: _brand, width: 1.4),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('COUNT SHEET NO.',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1, color: _brand)),
              pw.SizedBox(height: 2),
              pw.Text(countSheetNo,
                  style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.SizedBox(height: 4),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: countSheetNo,
                drawText: false,
                width: 120,
                height: 26,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(flex: 5, child: _kvBox('VEHICLE & VENDOR', system)),
        pw.SizedBox(width: 8),
        pw.Expanded(flex: 3, child: _kvBox('GATE', gate)),
        pw.SizedBox(width: 8),
        pw.Expanded(flex: 7, child: _handwrittenBox()),
      ],
    ),
    );
  }

  static pw.Widget _boxTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 7.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8, color: _brand)),
      );

  static pw.Widget _kvBox(String title, List<(String, String)> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _boxTitle(title),
          for (final (label, value) in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 62,
                    child: pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                  ),
                  pw.Expanded(
                    child: pw.Text(value,
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Received / Put Away / GRN, each with name, date and time to fill in,
  /// and the put-away supervisor.
  static pw.Widget _handwrittenBox() {
    pw.Widget blank(String label, {int flex = 1}) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            height: 20,
            margin: const pw.EdgeInsets.only(right: 4),
            padding: const pw.EdgeInsets.only(left: 3, top: 2),
            decoration: const pw.BoxDecoration(
              color: _writeFill,
              border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)),
            ),
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: _muted)),
          ),
        );
    pw.Widget row(String who, String dateLabel) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            blank(who, flex: 5),
            blank(dateLabel, flex: 3),
            blank('Time', flex: 2),
          ]),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _boxTitle('RECEIVING, PUT AWAY & GRN  (to be filled by warehouse)'),
          row('Received By', 'Check Date'),
          row('Put Away By', 'Put Away Date'),
          row('GRN By', 'GRN Date'),
          pw.Row(children: [blank('Put Away Supervisor Name', flex: 10)]),
        ],
      ),
    );
  }

  // ── Lines ────────────────────────────────────────────────────────────────

  static const _columns = <(String, double, pw.Alignment)>[
    ('Sr.', 22, pw.Alignment.center),
    ('Gate Entry No.', 98, pw.Alignment.centerLeft),
    ('Put Away\nLocation', 62, pw.Alignment.center),
    ('GRN No.', 60, pw.Alignment.center),
    ('Invoice No.', 86, pw.Alignment.centerLeft),
    ('Item Code', 84, pw.Alignment.centerLeft),
    ('No. of Boxes x\nQty per Box', 74, pw.Alignment.center),
    ('Box / Bin / Bag /\nPetty / Jali', 72, pw.Alignment.center),
    ('No. of\nPallet', 44, pw.Alignment.center),
    ('Qty', 58, pw.Alignment.centerRight),
    ('Storage Type\n(P1 / P2 / P3)', 0, pw.Alignment.center), // takes the rest
  ];

  static pw.Widget _linesTable({required List<_Line> lines, required int rowCount}) {
    final widths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < _columns.length; i++)
        i: _columns[i].$2 == 0
            ? const pw.FlexColumnWidth()
            : pw.FixedColumnWidth(_columns[i].$2),
    };

    pw.Widget cell(String text,
            {pw.Alignment align = pw.Alignment.centerLeft,
            bool bold = false,
            String? sub,
            double size = 8.5}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          constraints: const pw.BoxConstraints(minHeight: 19.5),
          child: sub == null || sub.isEmpty
              ? pw.Text(text,
                  style: pw.TextStyle(
                      fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(text,
                        style: pw.TextStyle(
                            fontSize: size,
                            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                    pw.Text(sub, style: const pw.TextStyle(fontSize: 6.5, color: _muted)),
                  ],
                ),
        );

    final header = pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: _headFill),
      children: [
        for (final (title, _, _) in _columns)
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: pw.Text(title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _ink)),
          ),
      ],
    );

    final rows = <pw.TableRow>[header];
    for (var i = 0; i < rowCount; i++) {
      final line = i < lines.length ? lines[i] : null;
      final zebra = i.isOdd ? const pw.BoxDecoration(color: _zebra) : null;
      if (line == null) {
        rows.add(pw.TableRow(decoration: zebra, children: [
          cell('${i + 1}', align: pw.Alignment.center, size: 7.5),
          for (var c = 1; c < _columns.length; c++) cell(''),
        ]));
        continue;
      }
      final qtyText = line.qty == null
          ? ''
          : '${_qty.format(line.qty)}${(line.uom ?? '').isEmpty ? '' : ' ${line.uom}'}';
      rows.add(pw.TableRow(decoration: zebra, children: [
        cell('${i + 1}', align: pw.Alignment.center, size: 7.5),
        cell(_safe(line.entry.gateEntryNo), bold: true, size: 7.8),
        cell(''),
        cell(''),
        cell(_safe(line.entry.challanNo), bold: true),
        cell(line.itemCode ?? '',
            bold: true,
            sub: (line.poNumber ?? '').isEmpty ? null : 'PO ${line.poNumber}'),
        cell(''),
        cell(''),
        cell(''),
        cell(qtyText, align: pw.Alignment.centerRight, bold: true),
        cell(''),
      ]));
    }

    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _ink, width: 0.9),
        bottom: pw.BorderSide(color: _ink, width: 0.9),
        left: pw.BorderSide(color: _ink, width: 0.9),
        right: pw.BorderSide(color: _ink, width: 0.9),
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
        verticalInside: pw.BorderSide(color: _rule, width: 0.5),
      ),
      children: rows,
    );
  }

  static pw.Widget _totalsRow({
    required int invoiceCount,
    required int lineCount,
    required num totalQty,
  }) {
    pw.Widget box(String label, String value, {bool write = false, int flex = 1}) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            height: 24,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            decoration: pw.BoxDecoration(
              color: write ? _writeFill : _headFill,
              border: pw.Border.all(color: _ink, width: 0.9),
            ),
            child: pw.Row(children: [
              pw.Text('$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
              pw.Expanded(
                child: pw.Text(value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),
        );
    return pw.Row(children: [
      box('Total Invoices:', '$invoiceCount'),
      box('Total Lines:', '$lineCount'),
      box('Total Boxes:', '', write: true, flex: 2),
      box('Total Pallets:', '', write: true),
      box('Total Qty:', _qty.format(totalQty), flex: 2),
    ]);
  }

  static pw.Widget _signatures({required String gateSecurity}) {
    pw.Widget sign(String role, {String name = ''}) => pw.Expanded(
          child: pw.Container(
            height: 40,
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _rule, width: 0.8),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(role.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6, color: _brand)),
                if (name.isNotEmpty)
                  pw.Text(name, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                pw.Spacer(),
                pw.Container(height: 0.6, color: _rule),
                pw.Text('Name & Signature', style: const pw.TextStyle(fontSize: 6, color: _muted)),
              ],
            ),
          ),
        );
    return pw.Row(children: [
      sign('Gate Security', name: gateSecurity),
      sign('Received By'),
      sign('Put Away By'),
      sign('GRN By'),
      sign('Put Away Supervisor'),
    ]);
  }

  static pw.Widget _footer({
    required String countSheetNo,
    required String printedBy,
    required DateTime printedAt,
    required int page,
    required int pages,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.6)),
      ),
      child: pw.Row(children: [
        pw.Text('Count Sheet $countSheetNo  |  Printed ${_dateTime.format(printedAt)}'
            '${printedBy.isEmpty ? '' : ' by $printedBy'}',
            style: const pw.TextStyle(fontSize: 7, color: _muted)),
        pw.Spacer(),
        pw.Text('Vistar Gate Reco  |  Page $page of $pages',
            style: const pw.TextStyle(fontSize: 7, color: _muted)),
      ]),
    );
  }
}

class _Line {
  _Line({required this.entry, this.itemCode, this.poNumber, this.qty, this.uom});

  final GateEntry entry;
  final String? itemCode;
  final String? poNumber;
  final num? qty;
  final String? uom;
}
