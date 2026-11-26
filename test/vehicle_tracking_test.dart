// Vehicle tracking: what the app reads from /vehicle-tracking.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_reco_app/features/vehicle_tracking/domain/vtt_models.dart';

void main() {
  test('durations read the way people say them', () {
    expect(durationLabel(null), '—');
    expect(durationLabel(35), '35m');
    expect(durationLabel(65), '1h 05m');
    expect(durationLabel(60 * 26 + 5), '1d 02h');
  });

  test('a board row on a trip', () {
    final row = VttBoardRow.fromJson({
      'vehicleId': 'v1',
      'vehicleNo': 'MH14AB2001',
      'category': 'Truck 10T',
      'trip': {
        'id': 't1',
        'vehicleId': 'v1',
        'vehicleNo': 'MH14AB2001',
        'status': 'open',
        'startedAt': '2026-11-26T04:00:00Z',
        'entries': [
          {
            'id': 'e1',
            'checkpoint': 'Gate In at Cytiva',
            'site': 'Cytiva',
            'at': '2026-11-26T03:50:00Z',
            'recordedAt': '2026-11-26T04:00:00Z',
            'recordedBy': 'Guard',
            'source': 'tap',
            'revised': true,
            'revisedBy': 'Guard',
            'revisionReason': 'Tapped late',
            'canRevise': true,
          },
        ],
        'remaining': ['Dock In at Cytiva', 'Loading done'],
        'totalMinutes': 40,
      },
      'lastCheckpoint': {'name': 'Gate In at Cytiva', 'at': '2026-11-26T03:50:00Z'},
      'nextCheckpoint': {'id': 'c2', 'name': 'Dock In at Cytiva'},
      'elapsedMinutes': 40,
      'targetMinutes': 30,
      'status': 'red',
      'stale': false,
      'canRecord': [
        {'id': 'c2', 'name': 'Dock In at Cytiva', 'site': 'Cytiva'},
      ],
    });
    expect(row.trip!.isOpen, isTrue);
    expect(row.trip!.entries.single.revised, isTrue);
    expect(row.trip!.entries.single.at!.isBefore(row.trip!.entries.single.recordedAt!), isTrue,
        reason: 'the corrected time counts, the original is kept');
    expect(row.trip!.remaining, ['Dock In at Cytiva', 'Loading done']);
    expect(row.nextCheckpoint, 'Dock In at Cytiva');
    expect(row.status, 'red');
    expect(row.canRecord.single.id, 'c2');
  });

  test('an idle vehicle and a checkpoint with targets', () {
    final idle = VttBoardRow.fromJson({
      'vehicleId': 'v2',
      'vehicleNo': 'MH14AB2002',
      'trip': null,
      'stale': false,
      'canRecord': [
        {'id': 'c1', 'name': 'Gate In', 'autoSource': 'gate_entry_in'},
      ],
      'lastTripEndedAt': '2026-11-25T10:00:00Z',
    });
    expect(idle.trip, isNull);
    expect(idle.canRecord.single.autoSource, 'gate_entry_in');
    expect(idle.lastTripEndedAt, isNotNull);

    final cp = VttCheckpoint.fromJson({
      'id': 'c2',
      'name': 'Dock In',
      'kind': 'dock_in',
      'isMandatory': false,
      'isActive': true,
      'users': [
        {'id': 'u1', 'name': 'Exec', 'role': 'warehouse_executive'},
      ],
      'targets': [
        {'categoryId': null, 'minutes': 30},
        {'categoryId': 'k1', 'minutes': 20},
      ],
    });
    expect(cp.isMandatory, isFalse);
    expect(cp.defaultTarget, 30);
    expect(cp.targetFor('k1'), 20);
    expect(cp.targetFor('k2'), isNull);
    expect(cp.users.single.name, 'Exec');
  });

  test('settings: off by default when the server says little', () {
    final s = VttSettings.fromJson({'canManage': true});
    expect(s.enabled, isFalse);
    expect(s.reviseWindowHours, 24);
    expect(s.amberPercent, 20);
    expect(s.canManage, isTrue);
  });
}
