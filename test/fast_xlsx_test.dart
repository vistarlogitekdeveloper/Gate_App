import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/reports/domain/services/fast_xlsx.dart';

void main() {
  test('buildXlsx produces a valid workbook at production row counts',
      () async {
    const rowCount = 17421; // the live Gate Entry Register volume
    const headers = [
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
    final rows = List<List<Object?>>.generate(
      rowCount,
      (i) => [
        'GE-2026-${i.toString().padLeft(6, '0')}',
        'CHLN/$i/AB',
        '15-09-2026',
        '09:41',
        '11:03',
        '1h 22m',
        'Vendor & Sons <Pvt> Ltd $i',
        'V${i % 900}',
        'PO-$i',
        'MH12AB${i % 10000}',
        'LR-$i',
        i % 500,
        'Material description $i',
      ],
    );

    var lastProgress = 0;
    final sw = Stopwatch()..start();
    final bytes = await buildXlsx(
      headers: headers,
      rows: rows,
      onProgress: (written, total) => lastProgress = written,
    );
    sw.stop();

    // ignore: avoid_print
    print('buildXlsx: $rowCount rows x ${headers.length} cols '
        '-> ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB '
        'in ${sw.elapsedMilliseconds} ms');

    expect(lastProgress, rowCount, reason: 'progress must reach the total');
    expect(bytes, isNotEmpty);

    // It must be a real zip with exactly the parts Excel requires.
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(
        names,
        containsAll(<String>[
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/worksheets/sheet1.xml',
        ]));

    final sheet = String.fromCharCodes(archive.files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);

    // header row + every data row
    expect('<row '.allMatches(sheet).length, rowCount + 1);
    // ampersand and angle brackets from the vendor name must be escaped
    expect(sheet.contains('Vendor &amp; Sons &lt;Pvt&gt; Ltd 5'), isTrue);
    expect(sheet.contains('Vendor & Sons <Pvt>'), isFalse);
    // qty must be a numeric cell, not an inline string
    expect(sheet.contains('<c r="L2"><v>0</v></c>'), isTrue);
    expect(sheet.contains('<c r="L3"><v>1</v></c>'), isTrue);
    // last column of the last row must use the right column letter
    expect(sheet.contains('r="M${rowCount + 1}"'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('column references roll over past Z', () async {
    final headers = List<String>.generate(30, (i) => 'H$i');
    final bytes = await buildXlsx(headers: headers, rows: const []);
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = String.fromCharCodes(archive.files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);
    expect(sheet.contains('r="Z1"'), isTrue);
    expect(sheet.contains('r="AA1"'), isTrue);
    expect(sheet.contains('r="AD1"'), isTrue);
  });

  test('control characters are stripped so the XML stays parseable', () async {
    final bytes = await buildXlsx(
      headers: const ['A'],
      rows: const [
        ['bad\u0000value\u0007here'],
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = String.fromCharCodes(archive.files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);
    expect(sheet.contains('badvaluehere'), isTrue);
  });
}
