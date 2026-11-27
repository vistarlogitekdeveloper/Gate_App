import 'package:intl/intl.dart';

import 'stock_models.dart';

/// The three stock reports (server: GET /stock/reports/<kind>).
enum StockReportKind { inward, outward, balance }

extension StockReportKindX on StockReportKind {
  String get title => switch (this) {
        StockReportKind.inward => 'Stock Inward Report',
        StockReportKind.outward => 'Stock Outward (Dispatch) Report',
        StockReportKind.balance => 'Stock Balance Report',
      };

  String get short => switch (this) {
        StockReportKind.inward => 'Stock Inward',
        StockReportKind.outward => 'Stock Outward (Dispatch)',
        StockReportKind.balance => 'Stock Balance',
      };

  String get apiKind => name;

  String get fileBase => switch (this) {
        StockReportKind.inward => 'Stock_Inward',
        StockReportKind.outward => 'Stock_Outward',
        StockReportKind.balance => 'Stock_Balance',
      };

  /// Inward / outward take a date range; balance takes "as of".
  bool get usesRange => this != StockReportKind.balance;
}

final _dateTime = DateFormat('dd-MM-yyyy hh:mm a');
final _date = DateFormat('dd-MM-yyyy');

String? _dt(Object? v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? s : _dateTime.format(d.toLocal());
}

String? _d(Object? v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? s : _date.format(d);
}

num? _n(Object? v) => v is num ? v : num.tryParse(v?.toString() ?? '');

class StockReportColumn {
  const StockReportColumn(this.header, this.value, {this.numeric = false});
  final String header;
  final Object? Function(Map<String, dynamic> row) value;
  final bool numeric;
}

List<StockReportColumn> stockReportColumns(StockReportKind kind) => switch (kind) {
      StockReportKind.inward => [
          StockReportColumn('Received On', (r) => _dt(r['receivedAt'])),
          StockReportColumn('Count Sheet', (r) => r['countSheetNo']),
          StockReportColumn('Invoice No', (r) => r['invoiceNo']),
          StockReportColumn('Vendor Code', (r) => r['vendorCode']),
          StockReportColumn('Vendor Name', (r) => r['vendorName']),
          StockReportColumn('Vehicle No', (r) => r['vehicleNo']),
          StockReportColumn('PO Number', (r) => r['poNumber']),
          StockReportColumn('Material', (r) => r['materialCode']),
          StockReportColumn('Description', (r) => r['description']),
          StockReportColumn('UOM', (r) => r['uom']),
          StockReportColumn('Received Qty', (r) => _n(r['received']), numeric: true),
          StockReportColumn('Dispatched Qty', (r) => _n(r['dispatched']), numeric: true),
          StockReportColumn('Balance Qty', (r) => _n(r['balance']), numeric: true),
        ],
      StockReportKind.outward => [
          StockReportColumn('Dispatched On', (r) => _dt(r['dispatchedAt'])),
          StockReportColumn('Gate Out Entry', (r) => r['gateEntryNo']),
          StockReportColumn('DC / Invoice No', (r) => r['dcNo']),
          StockReportColumn('DC Date', (r) => _d(r['dcDate'])),
          StockReportColumn('Customer Code', (r) => r['partyCode']),
          StockReportColumn('Customer', (r) => r['partyName']),
          StockReportColumn('Vehicle No', (r) => r['vehicleNo']),
          StockReportColumn('Transporter', (r) => r['transporter']),
          StockReportColumn('From Count Sheet', (r) => r['countSheetNo']),
          StockReportColumn('From Invoice', (r) => r['invoiceNo']),
          StockReportColumn('Supplier', (r) => r['supplierName']),
          StockReportColumn('PO Number', (r) => r['poNumber']),
          StockReportColumn('Material', (r) => r['materialCode']),
          StockReportColumn('Description', (r) => r['description']),
          StockReportColumn('UOM', (r) => r['uom']),
          StockReportColumn('Qty', (r) => _n(r['qty']), numeric: true),
          StockReportColumn('Gated Out On', (r) => _dt(r['gatedOutAt']) ?? 'Not yet'),
          StockReportColumn('Dispatched By', (r) => r['createdBy']),
        ],
      StockReportKind.balance => [
          StockReportColumn('Count Sheet', (r) => r['countSheetNo']),
          StockReportColumn('Received On', (r) => _dt(r['receivedAt'])),
          StockReportColumn('Invoice No', (r) => r['invoiceNo']),
          StockReportColumn('Vendor Name', (r) => r['vendorName']),
          StockReportColumn('Vehicle No', (r) => r['vehicleNo']),
          StockReportColumn('PO Number', (r) => r['poNumber']),
          StockReportColumn('Material', (r) => r['materialCode']),
          StockReportColumn('Description', (r) => r['description']),
          StockReportColumn('UOM', (r) => r['uom']),
          StockReportColumn('Received Qty', (r) => _n(r['received']), numeric: true),
          StockReportColumn('Dispatched Qty', (r) => _n(r['dispatched']), numeric: true),
          StockReportColumn('Balance Qty', (r) => _n(r['balance']), numeric: true),
        ],
    };

/// A cell as text (screen and PDF): quantities without trailing zeros.
String stockReportCellText(Object? v) {
  if (v == null) return '';
  if (v is num) return qtyLabel(v.toDouble());
  return v.toString();
}

/// Totals of the quantity columns, in column order (null for text columns).
List<num?> stockReportTotals(StockReportKind kind, List<Map<String, dynamic>> rows) {
  final cols = stockReportColumns(kind);
  return [
    for (final c in cols)
      c.numeric ? rows.fold<num>(0, (s, r) => s + ((c.value(r) as num?) ?? 0)) : null,
  ];
}

class StockReportResult {
  const StockReportResult({required this.rows, required this.truncated, required this.maxRows, this.asOf});
  final List<Map<String, dynamic>> rows;
  final bool truncated;
  final int maxRows;
  final DateTime? asOf;
}
