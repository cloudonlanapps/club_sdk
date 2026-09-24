import 'package:club_sdk_2/sdk/models/user_conflict_report.dart';
import 'package:test/test.dart';

void main() {
  group('UserConflictItem', () {
    test('fromMap parses username and nested events', () {
      final item = UserConflictItem.fromMap(const {
        'username': 'jdoe',
        'events': [
          {
            'eventId': 1,
            'eventTitle': 'Other Camp',
            'eventType': 'camp',
            'occurrences': [
              {
                'targetStartUtc': 1000,
                'targetEndUtc': 2000,
                'otherStartUtc': 1500,
                'otherEndUtc': 2500,
              },
            ],
          },
        ],
      });

      expect(item.username, 'jdoe');
      expect(item.events, hasLength(1));
      expect(item.events.first.eventId, 1);
      expect(item.events.first.occurrences, hasLength(1));
    });

    test('fromMap defaults missing events list to empty', () {
      final item = UserConflictItem.fromMap(const {'username': 'jdoe'});
      expect(item.events, isEmpty);
    });
  });

  group('UserConflictReport', () {
    test('empty map produces no conflicts', () {
      final report = UserConflictReport.fromMap(const {});
      expect(report.hasConflict, isFalse);
      expect(report.userConflicts, isEmpty);
    });

    test('parses a non-empty user_conflicts list', () {
      final report = UserConflictReport.fromMap(const {
        'userConflicts': [
          {
            'username': 'jdoe',
            'events': <Map<String, dynamic>>[],
          },
          {
            'username': 'aroe',
            'events': [
              {
                'eventId': 7,
                'eventTitle': 'Booked',
                'eventType': 'programme',
                'occurrences': <Map<String, dynamic>>[],
              },
            ],
          },
        ],
      });

      expect(report.hasConflict, isTrue);
      expect(report.userConflicts, hasLength(2));
      expect(report.userConflicts[0].username, 'jdoe');
      expect(report.userConflicts[1].events.first.eventId, 7);
    });

    test('equality uses deep collection equality', () {
      final a = UserConflictReport.fromMap(const {
        'userConflicts': [
          {'username': 'x', 'events': <Map<String, dynamic>>[]},
        ],
      });
      final b = UserConflictReport.fromMap(const {
        'userConflicts': [
          {'username': 'x', 'events': <Map<String, dynamic>>[]},
        ],
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('round-trips through toJson / fromJson', () {
      final original = UserConflictReport.fromMap(const {
        'userConflicts': [
          {
            'username': 'jdoe',
            'events': [
              {
                'eventId': 9,
                'eventTitle': 'Round Trip',
                'eventType': 'camp',
                'occurrences': [
                  {
                    'targetStartUtc': 1000,
                    'targetEndUtc': 2000,
                    'otherStartUtc': 1500,
                    'otherEndUtc': 2500,
                  },
                ],
              },
            ],
          },
        ],
      });
      final restored = UserConflictReport.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
