import 'dart:convert';

import 'package:archive/archive.dart';

/// Minimal streaming XLSX writer.
///
/// Why this exists instead of package:excel
/// ----------------------------------------
/// package:excel builds a full in-memory object model — one Dart object per
/// cell — and re-serialises the entire workbook inside `encode()`. At the
/// volumes this app actually exports (17,421 gate entries x 13 columns is
/// ~226,000 cells) that is minutes of CPU and hundreds of megabytes.
///
/// On Flutter **web** that cost lands squarely on the UI thread. `compute()`
/// does not spawn an isolate on web — its implementation is literally
/// `await null; return callback(message);` (see the Flutter SDK's
/// foundation/_isolates_web.dart). It pumps exactly one frame, which is just
/// enough to paint "Generating…", and then the tab locks up until the build
/// finishes. That is the "stuck export" bug.
///
/// SpreadsheetML is only a zip of XML, so we skip the object model entirely
/// and write the sheet straight out as text using inline strings. Work is
/// chunked: every [_rowsPerChunk] rows we report progress and yield with
/// `Future.delayed(Duration.zero)`, which hands control back to the browser's
/// event loop so it can actually paint. (`await null` yields only a
/// microtask — the browser never gets to render, so it would not help here.)
///
/// The output is a deliberately minimal but valid .xlsx: five parts, no
/// styles, no shared-string table. Excel, LibreOffice and Google Sheets all
/// open it.
const int _rowsPerChunk = 2000;

/// Builds a single-sheet .xlsx.
///
/// [rows] cells may be `String`, `num` or `null`. Strings are written as
/// inline strings, nums as native numeric cells (so Excel treats a quantity
/// as a number rather than left-aligned text), null as an empty cell.
///
/// [onProgress] is invoked with (rowsWritten, totalRows) roughly every
/// [_rowsPerChunk] rows and once at completion.
Future<List<int>> buildXlsx({
  required List<String> headers,
  required List<List<Object?>> rows,
  String sheetName = 'Sheet1',
  void Function(int rowsWritten, int totalRows)? onProgress,
}) async {
  final total = rows.length;
  final sheet = StringBuffer()
    ..write(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>');

  _writeRow(sheet, 1, headers);

  for (var i = 0; i < total; i++) {
    _writeRow(sheet, i + 2, rows[i]);
    if ((i + 1) % _rowsPerChunk == 0) {
      onProgress?.call(i + 1, total);
      // Macrotask yield: lets the browser paint the progress indicator.
      await Future<void>.delayed(Duration.zero);
    }
  }
  onProgress?.call(total, total);

  sheet.write('</sheetData></worksheet>');

  final archive = Archive()
    ..addFile(_part('[Content_Types].xml', _contentTypes))
    ..addFile(_part('_rels/.rels', _rootRels))
    ..addFile(_part('xl/workbook.xml', _workbook(sheetName)))
    ..addFile(_part('xl/_rels/workbook.xml.rels', _workbookRels))
    ..addFile(_part('xl/worksheets/sheet1.xml', sheet.toString()));

  // Give the UI one more frame before the zip step, which is a single
  // uninterruptible block of work.
  await Future<void>.delayed(Duration.zero);

  // BEST_SPEED is ZipEncoder's default; spelled out because at these sizes
  // the difference between it and BEST_COMPRESSION is seconds of dead UI.
  final bytes = ZipEncoder().encode(archive, level: Deflate.BEST_SPEED);
  if (bytes == null) {
    throw StateError('Failed to encode the spreadsheet.');
  }
  return bytes;
}

ArchiveFile _part(String name, String xml) {
  final data = utf8.encode(xml);
  return ArchiveFile(name, data.length, data);
}

void _writeRow(StringBuffer out, int rowNumber, List<Object?> cells) {
  out.write('<row r="$rowNumber">');
  for (var c = 0; c < cells.length; c++) {
    final value = cells[c];
    if (value == null) continue;
    final ref = '${_colRef(c)}$rowNumber';
    if (value is num) {
      out.write('<c r="$ref"><v>$value</v></c>');
    } else {
      final text = _escape(value.toString());
      if (text.isEmpty) continue;
      out.write(
          '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">$text</t></is></c>');
    }
  }
  out.write('</row>');
}

/// Spreadsheet column reference: 0 -> A, 25 -> Z, 26 -> AA.
String _colRef(int index) {
  var n = index + 1;
  final letters = <int>[];
  while (n > 0) {
    final rem = (n - 1) % 26;
    letters.add(65 + rem);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(letters.reversed);
}

/// XML-escapes a cell value and drops control characters that XML 1.0
/// forbids outright — API data has contained stray 0x00..0x1F bytes, and a
/// single one makes the whole workbook unreadable.
String _escape(String value) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    switch (rune) {
      case 0x26:
        out.write('&amp;');
      case 0x3C:
        out.write('&lt;');
      case 0x3E:
        out.write('&gt;');
      default:
        if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
          continue;
        }
        out.writeCharCode(rune);
    }
  }
  return out.toString();
}

const String _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '</Types>';

const String _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const String _workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '</Relationships>';

String _workbook(String sheetName) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';
