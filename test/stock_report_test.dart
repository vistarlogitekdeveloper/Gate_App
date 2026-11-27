// Stock reports: columns, cells and totals the Excel / PDF downloads use.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/stock/domain/stock_report.dart';

void main() {
  final balanceRows = <Map<String, dynamic>>[
    {
      'countSheetNo': '00001',
      'receivedAt': '2026-11-27T06:10:00Z',
      'invoiceNo': 'IDZIHD1215',
      'vendorName': 'SUPREME NONWOVEN INDUSTRIES P LTD',
      'materialCode': 'K204421',
      'received': 100,
      'dispatched': 60,
      'balance': 40,
    },
    {
      'countSheetNo': '00002',
      'invoiceNo': 'INV-2',
      'materialCode': 'K300',
      'received': '12.5',
      'dispatched': 0,
      'balance': '12.5',
    },
  ];

  test('every report has its columns, quantities last and numeric', () {
    for (final k in StockReportKind.values) {
      final cols = stockReportColumns(k);
      expect(cols, isNotEmpty);
      expect(cols.where((c) => c.numeric), isNotEmpty, reason: '${k.name} has a qty column');
    }
    expect(stockReportColumns(StockReportKind.balance).map((c) => c.header).toList().sublist(9),
        ['Received Qty', 'Dispatched Qty', 'Balance Qty']);
    expect(StockReportKind.balance.usesRange, isFalse);
    expect(StockReportKind.outward.usesRange, isTrue);
  });

  test('balance: 100 received, 60 dispatched, 40 left; totals add up', () {
    final cols = stockReportColumns(StockReportKind.balance);
    final first = [for (final c in cols) c.value(balanceRows.first)];
    expect(first[0], '00001');
    expect(first.sublist(9), [100, 60, 40]);
    final totals = stockReportTotals(StockReportKind.balance, balanceRows);
    expect(totals.sublist(9), [112.5, 60, 52.5]);
    expect(totals.first, isNull);
    expect(stockReportCellText(52.5), '52.5');
    expect(stockReportCellText(40), '40');
    expect(stockReportCellText(null), '');
  });

  test('outward: a dispatch not gated out yet says so', () {
    final cols = stockReportColumns(StockReportKind.outward);
    final row = {
      'dispatchedAt': '2026-11-27T07:00:00Z',
      'gateEntryNo': 'GE-20261127-0003-19',
      'dcNo': 'DC-5001',
      'dcDate': '2026-11-27',
      'partyName': 'Knorr Bremse Pune',
      'countSheetNo': '00001',
      'invoiceNo': 'IDZIHD1215',
      'materialCode': 'K204421',
      'qty': 60,
      'gatedOutAt': null,
    };
    final values = {for (final c in cols) c.header: c.value(row)};
    expect(values['DC Date'], '27-11-2026');
    expect(values['Qty'], 60);
    expect(values['Gated Out On'], 'Not yet');
    expect(values['From Count Sheet'], '00001');
  });
}
