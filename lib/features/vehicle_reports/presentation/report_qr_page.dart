import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/env.dart';
import '../data/vehicle_report_repository.dart';
import '../domain/vehicle_report.dart';

/// The full address a driver's phone opens from the QR code.
String reportUrl(VehicleReportLink link) => '${Env.baseUrl}${link.path}';

/// Built-in Helvetica covers Latin-1 only: anything else is dropped.
String _latin1(String s) =>
    String.fromCharCodes(s.runes.where((c) => c >= 32 && c <= 255));

/// The A4 poster for the gate: "scan to report your vehicle".
Future<Uint8List> buildReportQrPoster({
  required String url,
  required String organisation,
}) async {
  const purple = PdfColor.fromInt(0xFF7A1FB0);
  const pink = PdfColor.fromInt(0xFFE0218A);
  const ink = PdfColor.fromInt(0xFF1D1530);
  const muted = PdfColor.fromInt(0xFF6B6280);
  pw.MemoryImage? logo;
  try {
    final bytes = await rootBundle.load('assets/images/vistar_logo_print.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {}

  pw.Widget step(String n, String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(children: [
          pw.Container(
            width: 26,
            height: 26,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: purple, shape: pw.BoxShape.circle),
            child: pw.Text(n,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 15, color: ink))),
        ]),
      );

  final doc = pw.Document(title: 'Vehicle reporting QR', author: 'Vistar Logitek');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) pw.Image(logo, height: 54),
        pw.SizedBox(height: 10),
        pw.Container(height: 4, decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [purple, pink]))),
        pw.SizedBox(height: 22),
        pw.Text('VEHICLE REPORTING',
            style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: purple, letterSpacing: 2)),
        pw.SizedBox(height: 6),
        pw.Text('Drivers: scan this QR code before entering the gate',
            style: const pw.TextStyle(fontSize: 16, color: ink)),
        pw.SizedBox(height: 26),
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: pink, width: 3),
            borderRadius: pw.BorderRadius.circular(18),
          ),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
            data: url,
            width: 290,
            height: 290,
            color: ink,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Open your phone camera and point it at the code',
            style: const pw.TextStyle(fontSize: 12, color: muted)),
        pw.SizedBox(height: 26),
        pw.Container(
          width: 400,
          child: pw.Column(children: [
            step('1', 'Scan the QR code with your phone camera'),
            step('2', 'Fill vehicle number, vendor name, your name and mobile'),
            step('3', 'Press "Report at gate" and wait - security will call you'),
          ]),
        ),
        pw.Spacer(),
        pw.Text(_latin1(organisation),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 4),
        pw.Text(url, style: const pw.TextStyle(fontSize: 8, color: muted)),
      ],
    ),
  ));
  return doc.save();
}

/// Admin: the QR poster to print and put up outside the gate.
class ReportQrPage extends ConsumerStatefulWidget {
  const ReportQrPage({super.key});

  @override
  ConsumerState<ReportQrPage> createState() => _ReportQrPageState();
}

class _ReportQrPageState extends ConsumerState<ReportQrPage> {
  VehicleReportLink? _link;
  Uint8List? _poster;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool regenerate = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await ref.read(vehicleReportRepositoryProvider).link(regenerate: regenerate);
      final poster = await buildReportQrPoster(url: reportUrl(link), organisation: link.organisation);
      if (!mounted) return;
      setState(() {
        _link = link;
        _poster = poster;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a new QR code?'),
        content: const Text(
          'Every QR code printed so far stops working. Drivers who scan an old '
          'one see "QR code no longer in use". Print and put up the new poster '
          'right away.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Make new QR')),
        ],
      ),
    );
    if (ok == true && mounted) await _load(regenerate: true);
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Reporting QR'),
        actions: [
          if (link != null)
            IconButton(
              tooltip: 'Copy link',
              icon: const Icon(Icons.link_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reportUrl(link)));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Link copied'),
                ));
              },
            ),
          if (link != null)
            TextButton.icon(
              onPressed: _busy ? null : _regenerate,
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text('New QR code'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ]),
              ),
            )
          : _poster == null
              ? const Center(child: CircularProgressIndicator())
              : PdfPreview(
                  key: ValueKey(link?.path),
                  build: (_) async => _poster!,
                  pdfFileName: 'Vehicle-Reporting-QR.pdf',
                  initialPageFormat: PdfPageFormat.a4,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
    );
  }
}
