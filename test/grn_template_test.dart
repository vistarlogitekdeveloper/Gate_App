import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/sap/domain/services/grn_template_service.dart';

void main() {
  test('template is a valid workbook with exactly the expected headers',
      () async {
    final bytes = await buildGrnTemplateBytes();
    expect(String.fromCharCodes(bytes.take(2)), 'PK', reason: 'must be a zip');

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = String.fromCharCodes(archive.files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);

    for (final column in kGrnTemplateColumns) {
      expect(sheet.contains('>${column.header}<'), isTrue,
          reason: '${column.header} missing from the template');
    }
    // header row only — a sample row would be uploaded as a junk GRN
    expect('<row '.allMatches(sheet).length, 1);
  });

  test('required columns match what the server rejects a row for', () {
    // sapAdapter.service.js validateRow(): poNumber, materialCode, grnNumber,
    // postingDate must be present and grnQty must be > 0. If that list changes
    // server-side this test should fail and the template be updated with it.
    expect(grnTemplateRequiredHeaders..sort(), <String>[
      'grnNumber',
      'grnQty',
      'materialCode',
      'postingDate',
      'poNumber',
    ]..sort());
  });

  test('challanNo is offered, since reconciliation matches on it', () {
    final headers = kGrnTemplateColumns.map((c) => c.header);
    expect(headers, contains('challanNo'));
    // ...but it is not required — the parser falls back to referenceNo
    expect(
      kGrnTemplateColumns.firstWhere((c) => c.header == 'challanNo').isRequired,
      isFalse,
    );
  });
}
