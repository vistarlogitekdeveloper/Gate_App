import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/reports/domain/models/report_models.dart';
import 'package:gate_reco_app/features/reports/domain/services/report_export_service.dart';

GateEntryReportItem item(int i) => GateEntryReportItem(
      gateEntryNo: 'GE-2026-${i.toString().padLeft(6, '0')}',
      direction: i.isEven ? 'Gate In' : 'Gate Out',
      challanNo: 'CHLN/$i/AB',
      lrNo: 'LR-$i',
      date: DateTime(2026, 9, 15, 9, 41),
      gateOutDate: DateTime(2026, 9, 15, 11, 3),
      material: 'Material description $i',
      qty: i % 500,
      vendor: 'Vendor & Sons <Pvt> Ltd $i',
      vendorCode: 'V${i % 900}',
      transporter: 'Transporter $i',
      vehicleNo: 'MH12AB${i % 10000}',
      poNumber: 'PO-$i',
      status: 'closed',
    );

void main() {
  test('PDF renders the capped row count and reports progress to completion',
      () async {
    final service = ReportExportService();
    final rows = List<GateEntryReportItem>.generate(
        ReportExportService.pdfRowLimit, item);

    var last = 0;
    var ticks = 0;
    final sw = Stopwatch()..start();
    final bytes = await service.buildGateEntryPdfBytesForTest(
      rows,
      onProgress: (written, total) {
        last = written;
        ticks++;
        expect(total, rows.length);
      },
    );
    sw.stop();
    // ignore: avoid_print
    print('PDF ${rows.length} rows -> ${(bytes.length / 1024).toStringAsFixed(0)} kB '
        'in ${sw.elapsedMilliseconds} ms across $ticks progress ticks');

    expect(bytes.length, greaterThan(1000));
    // %PDF- magic number
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(last, rows.length, reason: 'progress must reach the total');
    // Chunked rendering must yield many times, not once — that is what keeps
    // the web UI painting.
    expect(ticks, greaterThan(10));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('PDF with no rows still produces a valid document', () async {
    final service = ReportExportService();
    final bytes = await service.buildGateEntryPdfBytesForTest(const []);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
