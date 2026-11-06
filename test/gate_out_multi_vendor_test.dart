// Gate out per count sheet, several vendors in one gate entry, and a vendor's
// POs / materials from Add / Edit Vendor: what the app reads and sends.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:gate_reco_app/features/gate_entry/data/dto/create_gate_entry_request.dart';
import 'package:gate_reco_app/features/gate_entry/domain/models/count_sheet.dart';
import 'package:gate_reco_app/features/vendor/domain/models/vendor.dart';
import 'package:gate_reco_app/features/vendor/domain/vendor_template_service.dart';

void main() {
  group('count sheet gate out', () {
    test('pendingGateOutCount is read from the server', () {
      final s = CountSheetSummary.fromJson({
        'countSheetNo': '00012',
        'entryCount': 3,
        'gatedOutCount': 1,
        'pendingGateOutCount': 2,
        'gateDirection': 'Gate In',
      });
      expect(s.pendingGateOutCount, 2);
      expect(s.canGateOut, isTrue);
    });

    test('an older server (no pendingGateOutCount): inward sheets still inside can gate out', () {
      final inside = CountSheetSummary.fromJson({
        'countSheetNo': '00013',
        'entryCount': 2,
        'gatedOutCount': 0,
        'gateDirection': 'Gate In',
      });
      expect(inside.pendingGateOutCount, 2);
      final out = CountSheetSummary.fromJson({
        'countSheetNo': '00014',
        'entryCount': 2,
        'gatedOutCount': 0,
        'gateDirection': 'Gate Out',
      });
      expect(out.canGateOut, isFalse);
      final done = CountSheetSummary.fromJson({
        'countSheetNo': '00015',
        'entryCount': 2,
        'gatedOutCount': 2,
        'pendingGateOutCount': 0,
        'gateDirection': 'Gate In',
      });
      expect(done.canGateOut, isFalse);
    });

    test('overdue vehicles carry their count sheet', () {
      final o = OverdueGateOut.fromJson({
        'id': 'e1',
        'gateEntryNo': 'GE-1',
        'countSheetNo': '00012',
        'vehicleNo': 'MH14KA4509',
        'minutesInside': 300,
      });
      expect(o.countSheetNo, '00012');
      final old = OverdueGateOut.fromJson({'id': 'e2', 'gateEntryNo': 'GE-2'});
      expect(old.countSheetNo, isNull);
    });
  });

  group('several vendors in one gate entry', () {
    test('an invoice of another vendor sends its vendor; one of the main vendor does not', () {
      const other = CreateGateEntryInvoiceEntryRequest(
        challanNo: 'INV-9',
        documentDate: '2026-11-06',
        poNumber: '4500000001',
        partNumber: 'K100',
        quantity: 10,
        uom: 'EA',
        vendorCode: '913721',
        vendorName: 'Beta Fasteners',
      );
      expect(other.toJson()['vendorCode'], '913721');
      expect(other.toJson()['vendorName'], 'Beta Fasteners');
      const main = CreateGateEntryInvoiceEntryRequest(
        challanNo: 'INV-1',
        documentDate: '2026-11-06',
        poNumber: '',
        partNumber: '',
        quantity: 0,
        uom: 'EA',
      );
      expect(main.toJson().containsKey('vendorCode'), isFalse);
      expect(main.toJson().containsKey('vendorName'), isFalse);
    });
  });

  group('vendor master', () {
    test('Add / Edit Vendor sends the PO list only when given', () {
      const withPos = VendorWriteRequest(
        vendorCode: 'V1',
        vendorName: 'Gamma',
        purchaseOrders: [
          VendorPoRow(poNumber: '4500000001', materialCode: 'K100'),
          VendorPoRow(poNumber: '4500000002'),
        ],
      );
      expect(withPos.toJson()['purchaseOrders'], [
        {'poNumber': '4500000001', 'materialCode': 'K100'},
        {'poNumber': '4500000002'},
      ]);
      const nameOnly = VendorWriteRequest(vendorName: 'Gamma Pvt Ltd');
      expect(nameOnly.toJson().containsKey('purchaseOrders'), isFalse);
      const cleared = VendorWriteRequest(purchaseOrders: []);
      expect(cleared.toJson()['purchaseOrders'], isEmpty);
    });

    test('the template has the import headers and is an xlsx', () async {
      expect(kVendorTemplateHeaders,
          ['Supplier code', 'Supplier name', 'Purchase order', 'Material']);
      final bytes = await buildVendorTemplateBytes();
      expect(bytes.take(2), [0x50, 0x4B], reason: 'xlsx is a zip');
    });
  });
}
