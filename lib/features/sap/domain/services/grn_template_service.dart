import '../../../reports/domain/services/export_file_helper.dart';
import '../../../reports/domain/services/fast_xlsx.dart';

/// One column of the GRN upload template.
class GrnTemplateColumn {
  const GrnTemplateColumn(this.header, {this.isRequired = false});

  /// Exact header text written into the template.
  final String header;

  /// True when the importer rejects the row if this is blank.
  final bool isRequired;
}

/// Columns of the SAP GRN upload template, in the order they appear.
///
/// The header text matters: the server matches columns by name. Its parser
/// (sapAdapter.service.js `normalize`) accepts several aliases per column —
/// `postingDate`, `posting_date` and `Posting Date` all work — and these are
/// the canonical spellings, the first alias it checks. A file produced from
/// this template therefore always matches, whatever the user renames later.
///
/// Required is defined by the server's `validateRow`: it rejects a row that is
/// missing poNumber, materialCode, grnNumber or postingDate, and rejects any
/// grnQty that is not greater than zero. Everything else is optional.
///
/// challanNo is optional to the parser but is what links a GRN to its gate
/// entry during reconciliation — without it the row lands as "Pending Gate
/// Entry" — so it sits directly after the required block.
const List<GrnTemplateColumn> kGrnTemplateColumns = <GrnTemplateColumn>[
  GrnTemplateColumn('grnNumber', isRequired: true),
  GrnTemplateColumn('poNumber', isRequired: true),
  GrnTemplateColumn('materialCode', isRequired: true),
  GrnTemplateColumn('postingDate', isRequired: true),
  GrnTemplateColumn('grnQty', isRequired: true),
  GrnTemplateColumn('challanNo'),
  GrnTemplateColumn('vendorCode'),
  GrnTemplateColumn('vendorName'),
];

/// Header names the importer will reject the row for if left blank.
List<String> get grnTemplateRequiredHeaders => kGrnTemplateColumns
    .where((column) => column.isRequired)
    .map((column) => column.header)
    .toList();

const String _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Builds the template workbook: one sheet, headers only.
///
/// Deliberately no sample data row. The parser treats every row under the
/// header as real data, so an example left in place would be uploaded as a
/// junk GRN — the guidance belongs in the UI, not in the file.
Future<List<int>> buildGrnTemplateBytes() {
  return buildXlsx(
    headers: kGrnTemplateColumns.map((column) => column.header).toList(),
    rows: const <List<Object?>>[],
    sheetName: 'GRN',
  );
}

/// Writes the template to the user's device (download on web, share sheet on
/// mobile).
Future<void> downloadGrnTemplate() async {
  final bytes = await buildGrnTemplateBytes();
  await getExportFileHelper().saveAndShare(
    fileName: 'GRN_Upload_Template.xlsx',
    bytes: bytes,
    mimeType: _xlsxMime,
  );
}
