// Count sheets: the gate entry models carry `countSheetNo`, the create
// request sends `countSheetId`, and the Count Sheets list parses.
//
// The freezed / json_serializable output for countSheetNo was added by hand
// (build_runner cannot run with this repo's pinned analyzer on the installed
// SDK), so copyWith, ==, hashCode and the JSON round trip are pinned here.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/gate_entry/data/dto/create_gate_entry_request.dart';
import 'package:gate_reco_app/features/gate_entry/data/dto/gate_entry_response.dart';
import 'package:gate_reco_app/features/gate_entry/domain/models/count_sheet.dart';
import 'package:gate_reco_app/features/gate_entry/domain/models/gate_entry.dart';
import 'package:gate_reco_app/features/reports/domain/models/report_models.dart';

Map<String, dynamic> _serverEntry({String? countSheetNo}) => {
      'id': 'e1',
      'gateEntryNo': 'GE-20261104-0001-11',
      'gateMovement': 'in',
      'challanNo': 'INV-1',
      'transporterName': 'VRL',
      'vehicleNo': 'MH12AB1234',
      'vendorName': 'Acme',
      'status': 'inward_created',
      'items': const [],
      if (countSheetNo != null) 'countSheetNo': countSheetNo,
    };

void main() {
  test('the server response carries the count sheet number', () {
    expect(GateEntryResponse.fromJson(_serverEntry(countSheetNo: '00012')).countSheetNo,
        '00012');
    expect(GateEntryResponse.fromJson(_serverEntry()).countSheetNo, isNull,
        reason: 'entries from before count sheets have none');
    expect(
        GateEntryResponse.fromJson(
                {..._serverEntry(), 'count_sheet_no': '00007'})
            .countSheetNo,
        '00007');
  });

  test('GateEntry keeps countSheetNo through copyWith, ==, hashCode and JSON', () {
    const a = GateEntry(
      id: 'e1',
      gateMovement: GateMovement.inMovement,
      challanNo: 'INV-1',
      transporterName: 'VRL',
      vehicleNo: 'MH12AB1234',
      vendorName: 'Acme',
      items: [],
      remark: 'r',
      countSheetNo: '00012',
    );
    expect(a.countSheetNo, '00012');
    expect(a.copyWith(remark: 'x').countSheetNo, '00012');
    expect(a.copyWith(countSheetNo: '00013').countSheetNo, '00013');
    expect(a.copyWith(countSheetNo: null).countSheetNo, isNull);
    expect(a == a.copyWith(), isTrue);
    expect(a.hashCode, a.copyWith().hashCode);
    expect(a == a.copyWith(countSheetNo: '00013'), isFalse);
    expect(a.toString(), contains('countSheetNo: 00012'));
    final json = a.toJson();
    expect(json['countSheetNo'], '00012');
    expect(GateEntry.fromJson(json).countSheetNo, '00012');
  });

  test('GateEntryResponse keeps countSheetNo through copyWith and ==', () {
    final r = GateEntryResponse.fromJson(_serverEntry(countSheetNo: '00012'));
    expect(r.copyWith(remark: 'x').countSheetNo, '00012');
    expect(r == r.copyWith(), isTrue);
    expect(r == r.copyWith(countSheetNo: '00001'), isFalse);
  });

  test('the report row keeps countSheetNo through copyWith, == and JSON', () {
    final item = GateEntryReportItem(
      gateEntryNo: 'GE-1',
      direction: 'Gate In',
      challanNo: 'INV-1',
      lrNo: '',
      date: DateTime.utc(2026, 11, 4),
      material: 'M1',
      qty: 3,
      vendor: 'Acme',
      vendorCode: 'V1',
      transporter: 'VRL',
      vehicleNo: 'MH12AB1234',
      poNumber: 'PO1',
      status: 'Pending',
      countSheetNo: '00012',
    );
    expect(item.copyWith(status: 'Closed').countSheetNo, '00012');
    expect(item == item.copyWith(), isTrue);
    expect(item == item.copyWith(countSheetNo: null), isFalse);
    expect(GateEntryReportItem.fromJson(item.toJson()).countSheetNo, '00012');
  });

  test('the create request sends the reserved count sheet, and only when there is one', () {
    final withSheet = const CreateGateEntryRequest(
      gateMovement: 'in',
      vendorCode: 'V1',
      vendorName: 'Acme',
      invoiceEntries: [],
      challanNo: 'INV-1',
      countSheetId: '7a1f1a7e-2c41-4b8e-9d6b-1d6f3a0f5b11',
    ).toJson();
    expect(withSheet['countSheetId'], '7a1f1a7e-2c41-4b8e-9d6b-1d6f3a0f5b11');
    final without = const CreateGateEntryRequest(
      gateMovement: 'in',
      vendorCode: 'V1',
      vendorName: 'Acme',
      invoiceEntries: [],
      challanNo: 'INV-1',
    ).toJson();
    expect(without.containsKey('countSheetId'), isFalse);
  });

  test('the Count Sheets list and a reservation parse', () {
    final s = CountSheetSummary.fromJson(const {
      'countSheetNo': '00012',
      'gateTimestamp': '2026-11-04T05:00:00.000Z',
      'gateOutTimestamp': null,
      'entryCount': 3,
      'gatedOutCount': 3,
      'itemCount': 4,
      'totalQuantity': 12.5,
      'vehicleNos': 'MH12AB1234',
      'gateDirection': 'Gate In',
      'createdBy': 'Guard One',
    });
    expect(s.countSheetNo, '00012');
    expect(s.entryCount, 3);
    expect(s.totalQuantity, 12.5);
    expect(s.allGatedOut, isTrue);
    expect(s.vendorNames, isNull);
    expect(ReservedCountSheet.tryParse(const {'id': 'x', 'countSheetNo': '00001'})?.countSheetNo,
        '00001');
    expect(ReservedCountSheet.tryParse(const {'id': ''}), isNull);
    expect(ReservedCountSheet.tryParse(null), isNull);
  });
}
