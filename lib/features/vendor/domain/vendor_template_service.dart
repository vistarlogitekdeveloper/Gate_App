import '../../reports/domain/services/export_file_helper.dart';
import '../../reports/domain/services/fast_xlsx.dart';

/// Columns of the vendor master upload (Import from Excel), in order.
///
/// The server matches the header row by name (vendorPoMaterials.js
/// `mapColumns`: "Supplier code" / "Supplier name" / any header containing
/// "Purchase order" / any containing "Material"), so a file made from this
/// template always imports, whatever is renamed later.
///
/// One row per purchase order and material: a vendor with three POs has
/// three rows, each repeating its code and name. A vendor with no PO is one
/// row with the PO and material left blank.
const List<String> kVendorTemplateHeaders = <String>[
  'Supplier code',
  'Supplier name',
  'Purchase order',
  'Material',
];

const String _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// The template workbook: the header row only. No sample row -- the importer
/// treats every row under the header as a real vendor, and the import
/// REPLACES the whole purchase vendor list.
Future<List<int>> buildVendorTemplateBytes() => buildXlsx(
      headers: kVendorTemplateHeaders,
      rows: const <List<Object?>>[],
      sheetName: 'Vendor Master',
    );

/// Saves the template on the device (download on web, Downloads / share
/// sheet on mobile).
Future<void> downloadVendorTemplate() async {
  final bytes = await buildVendorTemplateBytes();
  await getExportFileHelper().saveAndShare(
    fileName: 'Vendor_Master_Template.xlsx',
    bytes: bytes,
    mimeType: _xlsxMime,
  );
}
