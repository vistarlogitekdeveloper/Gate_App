// Vehicles reported outside the gate (driver's QR form): what the app reads,
// what Create Gate Entry sends, and the QR poster.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/gate_entry/data/dto/create_gate_entry_request.dart';
import 'package:gate_reco_app/features/vehicle_reports/domain/vehicle_report.dart';
import 'package:gate_reco_app/features/vehicle_reports/presentation/report_qr_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a waiting report from the API', () {
    final reported = DateTime.now().subtract(const Duration(minutes: 75));
    final r = VehicleReport.fromJson({
      'id': 'r1',
      'vehicleNo': 'MH12AB1234',
      'vendorCode': '918912',
      'vendorName': 'Vishal Engineers Pvt. Ltd.',
      'driverName': 'Ramesh',
      'driverContactNo': '9876543210',
      'status': 'waiting',
      'reportedAt': reported.toUtc().toIso8601String(),
      'minutesWaiting': 75,
    });
    expect(r.isWaiting, isTrue);
    expect(r.vehicleNo, 'MH12AB1234');
    expect(r.waitedMinutes, inInclusiveRange(74, 76));
    expect(r.waitedLabel, startsWith('1h '));
  });

  test('a closed report: waited from reporting to entry', () {
    final r = VehicleReport.fromJson({
      'id': 'r2',
      'vehicleNo': 'MH14KA0001',
      'driverContactNo': '9000000000',
      'status': 'entered',
      'reportedAt': '2026-11-26T04:00:00Z',
      'closedAt': '2026-11-26T04:23:00Z',
      'gateEntryNo': 'GE-20261126-0001-12',
      'countSheetNo': '13200',
    });
    expect(r.isWaiting, isFalse);
    expect(r.waitedLabel, '23m');
    expect(r.countSheetNo, '13200');
    expect(r.vendorName, isNull);
  });

  test('Create Gate Entry sends the report it is for', () {
    CreateGateEntryRequest req({String? reportId}) => CreateGateEntryRequest(
          gateMovement: 'in',
          vendorCode: '',
          vendorName: '',
          invoiceEntries: const [
            CreateGateEntryInvoiceEntryRequest(
              challanNo: 'INV-1',
              documentDate: '2026-11-26',
              poNumber: '',
              partNumber: '',
              quantity: 1,
              uom: 'EA',
            ),
          ],
          vehicleReportId: reportId,
        );
    expect(req(reportId: 'r1').toJson()['vehicleReportId'], 'r1');
    expect(req().toJson().containsKey('vehicleReportId'), isFalse);
  });

  test('the QR poster builds', () async {
    final bytes = await buildReportQrPoster(
      url: 'https://api.vistarlogitek.com/api/v1/gate/report/abcdefghijklmnopqrstuvwx',
      organisation: 'Knorr-Bremse Pune',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Set REPORT_QR_PDF_OUT to a folder to look at the poster.
    final dir = Platform.environment['REPORT_QR_PDF_OUT'];
    if (dir != null && dir.isNotEmpty) {
      await File('$dir/report-qr-poster.pdf').writeAsBytes(bytes);
    }
  });
}
