import 'package:club_sdk_2/sdk/models/conflict_report.dart';
import 'package:test/test.dart';

void main() {
  group('OccurrencePair', () {
    test('fromMap accepts millisecond epoch ints', () {
      final pair = OccurrencePair.fromMap(const {
        'targetStartUtc': 1000,
        'targetEndUtc': 2000,
        'otherStartUtc': 1500,
        'otherEndUtc': 2500,
      });

      expect(pair.targetStartUtc.millisecondsSinceEpoch, 1000);
      expect(pair.targetEndUtc.millisecondsSinceEpoch, 2000);
      expect(pair.otherStartUtc.millisecondsSinceEpoch, 1500);
      expect(pair.otherEndUtc.millisecondsSinceEpoch, 2500);
    });

    test('round-trips through toMap', () {
      final pair = OccurrencePair.fromMap(const {
        'targetStartUtc': 1000,
        'targetEndUtc': 2000,
        'otherStartUtc': 1500,
        'otherEndUtc': 2500,
      });
      final restored = OccurrencePair.fromMap(pair.toMap());
      expect(restored, pair);
    });
  });

  group('EventConflictItem', () {
    test('fromMap parses event metadata and nested occurrences', () {
      final item = EventConflictItem.fromMap(const {
        'eventId': 42,
        'eventTitle': 'Existing Camp',
        'eventType': 'camp',
        'occurrences': [
          {
            'targetStartUtc': 1000,
            'targetEndUtc': 2000,
            'otherStartUtc': 1500,
            'otherEndUtc': 2500,
          },
        ],
      });

      expect(item.eventId, 42);
      expect(item.eventTitle, 'Existing Camp');
      expect(item.eventType, 'camp');
      expect(item.occurrences, hasLength(1));
      expect(
        item.occurrences.first.targetStartUtc.millisecondsSinceEpoch,
        1000,
      );
    });

    test('fromMap defaults missing occurrence list to empty', () {
      final item = EventConflictItem.fromMap(const {
        'eventId': 1,
        'eventTitle': 'X',
        'eventType': 'camp',
      });

      expect(item.occurrences, isEmpty);
    });
  });

  group('ConflictReport', () {
    test('empty map produces no conflicts', () {
      final report = ConflictReport.fromMap(const {});
      expect(report.hasConflict, isFalse);
      expect(report.venueConflicts, isEmpty);
      expect(report.organizerConflicts, isEmpty);
      expect(report.coachConflicts, isEmpty);
    });

    test('parses each per-actor list independently', () {
      final report = ConflictReport.fromMap(const {
        'venueConflicts': [
          {
            'eventId': 1,
            'eventTitle': 'A',
            'eventType': 'camp',
            'occurrences': [
              {
                'targetStartUtc': 0,
                'targetEndUtc': 100,
                'otherStartUtc': 50,
                'otherEndUtc': 150,
              },
            ],
          },
        ],
        'organizerConflicts': [
          {
            'eventId': 2,
            'eventTitle': 'B',
            'eventType': 'camp',
            'occurrences': <Map<String, dynamic>>[],
          },
        ],
        'coachConflicts': [
          {
            'eventId': 3,
            'eventTitle': 'C',
            'eventType': 'programme',
            'occurrences': <Map<String, dynamic>>[],
          },
        ],
      });

      expect(report.hasConflict, isTrue);
      expect(report.venueConflicts, hasLength(1));
      expect(report.venueConflicts.first.eventId, 1);
      expect(report.organizerConflicts, hasLength(1));
      expect(report.organizerConflicts.first.eventId, 2);
      expect(report.coachConflicts, hasLength(1));
      expect(report.coachConflicts.first.eventType, 'programme');
    });

    test('hasConflict is true when only coach list is populated', () {
      final report = ConflictReport.fromMap(const {
        'coachConflicts': [
          {
            'eventId': 9,
            'eventTitle': 'Z',
            'eventType': 'camp',
            'occurrences': <Map<String, dynamic>>[],
          },
        ],
      });
      expect(report.hasConflict, isTrue);
      expect(report.venueConflicts, isEmpty);
      expect(report.organizerConflicts, isEmpty);
    });

    test('equality uses deep collection equality', () {
      final a = ConflictReport.fromMap(const {
        'venueConflicts': [
          {
            'eventId': 1,
            'eventTitle': 'A',
            'eventType': 'camp',
            'occurrences': <Map<String, dynamic>>[],
          },
        ],
      });
      final b = ConflictReport.fromMap(const {
        'venueConflicts': [
          {
            'eventId': 1,
            'eventTitle': 'A',
            'eventType': 'camp',
            'occurrences': <Map<String, dynamic>>[],
          },
        ],
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('round-trips through toJson / fromJson', () {
      final original = ConflictReport.fromMap(const {
        'venueConflicts': [
          {
            'eventId': 7,
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
      });
      final restored = ConflictReport.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
