import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 7: the public event projection reports the age band, the window it
/// comes to and the day it is counted on (club_server#16).
void main() {
  group('Issue 7: PublicEvent age band', () {
    final referenceDay = DateTime.utc(2027, 1, 1);
    Map<String, dynamic> payload() => {
      'publicId': 'ev_abc',
      'title': 'test_U12 camp',
      'description': 'D',
      'type': 'camp',
      'venueId': 'vn_abc',
      'rrule': 'FREQ=DAILY;COUNT=3',
      'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
      'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
      'untilTimeUtc': null,
      'sessions': null,
      'gender': null,
      'minAge': {'years': 8, 'months': 0, 'days': 0},
      'maxAge': null,
      'strictAge': true,
      'dobOnOrAfterUtc': null,
      'dobOnOrBeforeUtc': DateTime.utc(2019).millisecondsSinceEpoch,
      'eligibilityReferenceDayUtc': referenceDay.millisecondsSinceEpoch,
      'isFeatured': false,
      'isPast': false,
      'cover': null,
      'gallery': <dynamic>[],
      'venue': {'publicId': 'vn_abc', 'name': 'Rink'},
      'coaches': <dynamic>[],
      'createdAtUtc': DateTime.utc(2026, 1, 1, 9).millisecondsSinceEpoch,
      'updatedAtUtc': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
    };

    test('fromMap reads the band, the window and the reference day', () {
      final e = PublicEvent.fromMap(payload());
      expect(e.minAge, const Age(years: 8));
      expect(e.maxAge, isNull);
      expect(e.strictAge, isTrue);
      expect(e.dobOnOrAfterUtc, isNull);
      expect(e.dobOnOrBeforeUtc, DateTime.utc(2019));
      expect(e.eligibilityReferenceDayUtc, referenceDay);
    });

    test('an event from a server that predates the band reads no ages, '
        'relaxed and no reference day', () {
      final e = PublicEvent.fromMap(
        payload()
          ..remove('minAge')
          ..remove('maxAge')
          ..remove('strictAge')
          ..remove('eligibilityReferenceDayUtc'),
      );
      expect(e.minAge, isNull);
      expect(e.maxAge, isNull);
      expect(e.strictAge, isFalse);
      expect(e.eligibilityReferenceDayUtc, isNull);
    });

    test('toMap/fromMap and toJson/fromJson round-trip the band', () {
      final e = PublicEvent.fromMap(payload());
      expect(e.toMap()['minAge'], {'years': 8, 'months': 0, 'days': 0});
      expect(e.toMap()['strictAge'], isTrue);
      expect(PublicEvent.fromMap(e.toMap()), e);
      expect(PublicEvent.fromJson(e.toJson()), e);
    });

    test('the band and the reference day take part in equality, and a '
        'bound is cleared through copyWith', () {
      final e = PublicEvent.fromMap(payload());
      expect(e.hashCode, PublicEvent.fromMap(payload()).hashCode);
      expect(e, isNot(e.copyWith(maxAge: () => const Age(years: 12))));
      expect(e, isNot(e.copyWith(strictAge: false)));
      expect(
        e,
        isNot(
          e.copyWith(
            eligibilityReferenceDayUtc: () => DateTime.utc(2027, 1, 2),
          ),
        ),
      );
      expect(e.copyWith(minAge: () => null).minAge, isNull);
    });
  });
}
