// Stock & dispatch: what the app reads from /stock and sends to dispatch.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/stock/data/stock_repository.dart';
import 'package:gate_reco_app/features/stock/domain/stock_models.dart';

void main() {
  test('quantities read the way they are written', () {
    expect(qtyLabel(100), '100');
    expect(qtyLabel(12.5), '12.5');
    expect(qtyLabel(0.3333), '0.3333');
    expect(qtyLabel(40.0), '40');
  });

  test('a count sheet from the list: received 100, dispatched 60, balance 40', () {
    final s = StockSheet.fromJson({
      'countSheetNo': '00001',
      'vehicleNo': 'MH12XP1771',
      'vendors': ['SUPREME NONWOVEN INDUSTRIES P LTD'],
      'invoices': ['IDZIHD1215'],
      'received': 100,
      'dispatched': 60,
      'balance': 40,
      'dispatches': 1,
      'lines': [
        {
          'entryId': 'e1',
          'countSheetNo': '00001',
          'invoiceNo': 'IDZIHD1215',
          'poNumber': 'PO100',
          'materialCode': 'K204421',
          'received': 100,
          'dispatched': 60,
          'balance': 40,
        },
      ],
    });
    expect(s.balance, 40);
    expect(s.dispatchCount, 1, reason: 'the list sends a count');
    expect(s.dispatches, isEmpty);
    final l = s.lines.single;
    expect(l.key, 'e1|PO100|K204421');
    expect(l.title, 'K204421');
  });

  test('one sheet with its dispatches', () {
    final s = StockSheet.fromJson({
      'countSheetNo': '00001',
      'received': '100',
      'dispatched': '60',
      'balance': '40',
      'lines': [],
      'dispatches': [
        {
          'id': 'o1',
          'gateEntryNo': 'GE-20261127-0003-11',
          'challanNo': 'DC-7',
          'partyName': 'Customer One',
          'createdAt': '2026-11-27T06:00:00Z',
          'gatedOutAt': null,
          'lines': [
            {'invoiceNo': 'IDZIHD1215', 'materialCode': 'K204421', 'qty': 60},
          ],
        },
      ],
    });
    expect(s.received, 100, reason: 'numbers may come as strings');
    expect(s.dispatchCount, 1);
    expect(s.dispatches.single.gatedOutAt, isNull);
    expect(s.dispatches.single.lines.single.qty, 60);
  });

  test('a dispatch line sends what the server keys the balance by', () {
    const line = StockLine(
      entryId: 'e1',
      countSheetNo: '00001',
      invoiceNo: 'INV',
      materialCode: 'K204421',
      received: 100,
      dispatched: 0,
      balance: 100,
    );
    expect(const DispatchLineInput(line: line, qty: 60).toJson(),
        {'entryId': 'e1', 'poNumber': '', 'materialCode': 'K204421', 'qty': 60.0});
  });
}
