import 'package:flutter_test/flutter_test.dart';

import 'package:gate_reco_app/features/gate_entry/domain/models/gate_entry.dart';
import 'package:gate_reco_app/features/gate_entry/domain/services/dc_qr.dart';

// KB, 2026-11-14: QR Dispatch's delivery challan carries a QR with its details;
// Finish loading made the vehicle's Gate Out entry. The guard scans the DC
// and the app opens that entry for Gate Out.
GateEntry _entry(String id, String challan, GateMovement m, {String vehicle = 'MH12HV3444'}) => GateEntry(
      id: id,
      gateMovement: m,
      challanNo: challan,
      transporterName: '',
      vehicleNo: vehicle,
      vendorName: 'KB Components',
      items: const [],
    );

void main() {
  const printed = 'DELIVERY CHALLAN DC2026000007\n'
      'Date: 14-11-2026 10:32, Shift 1ST\n'
      'Vehicle: MH12HV3444\n'
      'From: Vistar Logitek\n'
      '1. K099279 Body: 500 pcs, 2 BOX\n'
      'Total: 500 pcs, 2 BOX';

  test('reads the DC number and vehicle from the challan QR', () {
    final qr = parseDcQr(printed);
    expect(qr, isNotNull);
    expect(qr!.dcNo, 'DC2026000007');
    expect(qr.vehicleNo, 'MH12HV3444');
  });

  test('a bare DC number (typed, or a plain barcode) works too', () {
    expect(parseDcQr('  dc2026000007 ')!.dcNo, 'DC2026000007');
    expect(parseDcQr(' dc2026000007 ')!.vehicleNo, isNull);
  });

  test('anything else is not a delivery challan', () {
    expect(parseDcQr(''), isNull);
    expect(parseDcQr('eyJhbGciOiJSUzI1NiJ9.e-invoice'), isNull);
    expect(parseDcQr('https://example.com'), isNull);
  });

  test('picks the Gate Out entry of that DC, never an inward one with the same number', () {
    final list = [
      _entry('a', 'DC2026000007', GateMovement.inMovement),
      _entry('b', 'dc2026000007', GateMovement.outMovement),
      _entry('c', 'DC2026000008', GateMovement.outMovement),
    ];
    expect(pickOutEntry(list, 'DC2026000007')!.id, 'b');
    expect(pickOutEntry(list, 'DC2026000099'), isNull);
  });

  test('vehicle numbers match however they are written; a different lorry is flagged', () {
    expect(vehicleMismatch('MH12HV3444', 'MH 12 HV 3444'), isFalse);
    expect(vehicleMismatch('MH12-HV-3444', 'mh12hv3444'), isFalse);
    expect(vehicleMismatch('MH12HV3444', 'MH12HV3445'), isTrue);
    expect(vehicleMismatch(null, 'MH12HV3444'), isFalse, reason: 'nothing to compare');
  });
}
