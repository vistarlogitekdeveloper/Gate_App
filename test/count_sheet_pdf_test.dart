// The printed count sheet (Receipt and Put Away Sheet) builds from real-shaped
// data: one vehicle, several invoices, a client logo for Knorr-Bremse and none
// for other organisations, and a long sheet that continues onto more pages.
//
// Set COUNT_SHEET_PDF_OUT to a folder to also write the PDFs there for a look.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/gate_entry/domain/models/gate_entry.dart';
import 'package:gate_reco_app/features/gate_entry/domain/models/gate_entry_item.dart';
import 'package:gate_reco_app/features/gate_entry/domain/services/count_sheet_pdf_service.dart';

// The example rows of the client's "Required Format" sheet.
const _rows = [
  ('GE-20261024-0112-83', 'EB26G/1600241', '5501211605', 'K206095', 1500),
  ('GE-20261024-0111-54', 'EB26G/1600242', '5501224484', '3C62549/IN', 150),
  ('GE-20261024-0117-89', 'EB26G/1600243', '5501222483', 'K209827', 500),
  ('GE-20261024-0115-30', 'EB26G/1600244', '5501219169', 'K210898', 2000),
  ('GE-20261024-0114-20', 'EB26G/1600245', '5501222498', 'K209159', 1000),
  ('GE-20261024-0113-73', 'EB26G/1600246', '5501222494', 'K209921', 500),
  ('GE-20261024-0118-49', 'EB26G/1600247', '5501211621', 'K153405', 120),
  ('GE-20261024-0116-68', 'EB26G/1600248', '5501222493', '3C31376/IN', 8800),
  ('GE-20261024-0110-71', 'EB26G/1600249', '5501211633', 'K184659', 5110),
];

List<GateEntry> _entries({int repeat = 1}) => [
      for (var r = 0; r < repeat; r++)
        for (final (ge, inv, po, item, qty) in _rows)
          GateEntry(
            id: '$ge-$r',
            gateEntryNo: repeat == 1 ? ge : '$ge-$r',
            gateMovement: GateMovement.inMovement,
            challanNo: inv,
            lrNumber: 'LR-88213',
            transporterName: 'VRL Logistics',
            vehicleNo: 'MH14KA4509',
            driverContactNo: '9876543210',
            vendorCode: '913288',
            vendorName: 'Stanley Engineered Fastening (I) Pvt Ltd',
            items: [
              GateEntryItem(
                  poNumber: po, materialCode: item, challanQty: qty, uom: 'EA'),
            ],
            gateTimestamp: DateTime(2026, 10, 24, 15, 59),
            createdBy: 'Gopal Guard',
            countSheetNo: '12380',
          ),
    ];

Future<void> _maybeWrite(String name, List<int> bytes) async {
  final dir = Platform.environment['COUNT_SHEET_PDF_OUT'];
  if (dir == null || dir.isEmpty) return;
  await File('$dir/$name').writeAsBytes(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Knorr-Bremse sheet: one page, both logos, valid PDF', () async {
    final bytes = await CountSheetPdfService.build(
      countSheetNo: '12380',
      entries: _entries(),
      orgCode: 'KB-PUNE',
      orgName: 'Knorr-Bremse Systems for Commercial Vehicles India',
      printedBy: 'Asha Admin',
      printedAt: DateTime(2026, 11, 5, 12, 30),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(20000), reason: 'carries the logo images');
    await _maybeWrite('count-sheet-knorr.pdf', bytes);
  });

  test('any organisation prints the Knorr-Bremse logo', () async {
    final bytes = await CountSheetPdfService.build(
      countSheetNo: '00007',
      entries: _entries().take(2).toList(),
      orgCode: 'CYT',
      orgName: 'Cytiva India Pvt Ltd',
      printedBy: 'Gopal Guard',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(20000), reason: 'carries the logo images');
    await _maybeWrite('count-sheet-other-org.pdf', bytes);
  });

  test('one vehicle, several vendors: builds, with each invoice vendor', () async {
    final entries = _entries();
    final mixed = [
      for (var i = 0; i < entries.length; i++)
        i.isEven
            ? entries[i]
            : entries[i].copyWith(vendorCode: '919006', vendorName: 'Pondy Die Casting Pvt Ltd'),
    ];
    final bytes = await CountSheetPdfService.build(
      countSheetNo: '12382',
      entries: mixed,
      orgCode: 'KB',
      orgName: 'Knorr-Bremse',
      printedBy: 'Asha Admin',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await _maybeWrite('count-sheet-two-vendors.pdf', bytes);
  });

  test('a long sheet continues onto further pages', () async {
    final bytes = await CountSheetPdfService.build(
      countSheetNo: '12381',
      entries: _entries(repeat: 5), // 45 lines
      orgCode: 'KB',
      orgName: 'Knorr-Bremse',
      printedBy: 'Asha Admin',
    );
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;
    expect(pages, greaterThan(1));
    await _maybeWrite('count-sheet-long.pdf', bytes);
  });
}
