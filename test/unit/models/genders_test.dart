import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 14: an event's and a group's gender criterion is a list
/// (club_server#25, #26). Empty is no criterion. The single `gender` is
/// read from a server from before the list, and stays for one release as
/// the one gender of a list of one.
void main() {
  const three = [Gender.male, Gender.other, Gender.preferNotToSay];
  const threeOnServer = ['male', 'other', 'prefer_not_to_say'];
  final at = DateTime.utc(2027, 1, 4, 10).millisecondsSinceEpoch;

  Map<String, dynamic> eventMap(Map<String, dynamic> criterion) => {
    'id': 1,
    'title': 'T',
    'description': '',
    'type': 'camp',
    'visibility': 'public',
    'venueId': 1,
    'startTimeUtc': at,
    'endTimeUtc': at,
    'createdAtUtc': at,
    'updatedAtUtc': at,
    ...criterion,
  };

  Map<String, dynamic> groupMap(Map<String, dynamic> criterion) => {
    'id': 1,
    'name': 'G',
    'kind': 'auto',
    'createdAtUtc': at,
    ...criterion,
  };

  Map<String, dynamic> publicEventMap(Map<String, dynamic> criterion) => {
    'publicId': 'p1',
    'title': 'T',
    'type': 'camp',
    'venueId': 'v1',
    'startTimeUtc': at,
    'endTimeUtc': at,
    'venue': {'publicId': 'v1', 'name': 'Rink'},
    'createdAtUtc': at,
    'updatedAtUtc': at,
    ...criterion,
  };

  group('Issue 14: genders on Event', () {
    test('Issue 14: reads the list the server sends', () {
      final event = Event.fromMap(eventMap({'genders': threeOnServer}));
      expect(event.genders, three);
      expect(event.gender, isNull);
    });

    test('Issue 14: an empty list is no criterion', () {
      final event = Event.fromMap(eventMap({'genders': <String>[]}));
      expect(event.genders, isEmpty);
      expect(event.gender, isNull);
    });

    test('Issue 14: reads the single gender of an older server', () {
      final event = Event.fromMap(eventMap({'gender': 'female'}));
      expect(event.genders, [Gender.female]);
      expect(event.gender, Gender.female);
    });

    test('Issue 14: no gender key at all is no criterion', () {
      expect(Event.fromMap(eventMap({})).genders, isEmpty);
    });

    test('Issue 14: survives a map round trip and counts in equality', () {
      final event = Event.fromMap(eventMap({'genders': threeOnServer}));
      expect(event.toMap()['genders'], threeOnServer);
      expect(Event.fromMap(event.toMap()), event);
      expect(event.copyWith(genders: const [Gender.male]), isNot(event));
      expect(event.copyWith(genders: const []).genders, isEmpty);
    });

    test('Issue 14: EventInput carries the list both ways', () {
      final event = Event.fromMap(eventMap({'genders': threeOnServer}));
      final input = EventInput.fromEvent(event);
      expect(input.genders, three);
      expect(
        input.toEvent(id: 1, now: DateTime.utc(2027)).genders,
        three,
      );
      expect(EventInput.fromMap(input.toMap()).genders, three);
    });
  });

  group('Issue 14: genders on PublicEvent', () {
    test('Issue 14: reads the list, and the single gender of an older '
        'server', () {
      expect(
        PublicEvent.fromMap(publicEventMap({'genders': threeOnServer})).genders,
        three,
      );
      final older = PublicEvent.fromMap(publicEventMap({'gender': 'male'}));
      expect(older.genders, [Gender.male]);
      expect(older.gender, Gender.male);
    });
  });

  group('Issue 14: genders on Group', () {
    test('Issue 14: reads the list the server sends', () {
      final g = Group.fromMap(groupMap({'genders': threeOnServer}));
      expect(g.genders, three);
      expect(g.gender, isNull);
    });

    test('Issue 14: reads the single gender of an older server', () {
      final g = Group.fromMap(groupMap({'gender': 'other'}));
      expect(g.genders, [Gender.other]);
      expect(g.gender, Gender.other);
    });

    test('Issue 14: survives a map round trip and counts in equality', () {
      final g = Group.fromMap(groupMap({'genders': threeOnServer}));
      expect(g.toMap()['genders'], threeOnServer);
      expect(Group.fromMap(g.toMap()), g);
      expect(g.copyWith(genders: const []), isNot(g));
    });
  });
}
