import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/reports/domain/services/report_export_service.dart';

void main() {
  test('pdfRowLimit stays at the measured safe ceiling', () {
    // Measured on the Dart VM with the chunked table layout; a browser is
    // several times slower again:
    //     500 -> 0.8 s,  1,000 -> 0.9 s,  2,000 -> 4.6 s,  17,421 -> 45.5 s
    // Raising this without re-measuring on web is how the export last became
    // a hang. Excel has no cap and handles the full data set in under a
    // second, so send people there instead of raising this.
    expect(ReportExportService.pdfRowLimit, 1000);
  });
}
