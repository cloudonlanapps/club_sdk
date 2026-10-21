import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/remote_store/sources/group_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 14: event and group writes send `genders`, a list (club_server#25,
/// #26); the server never sees `gender`. Issue 39: the deprecated single
/// `gender` parameter is gone.
({RemoteEventSource events, RemoteGroupSource groups, List<http.Request> sent})
_harness() {
  final sent = <http.Request>[];
  final at = DateTime.utc(2027, 1, 4, 10).millisecondsSinceEpoch;
  final mockClient = MockClient((request) async {
    sent.add(request);
    final isGroup = request.url.path.contains('/groups');
    final body = isGroup
        ? {'id': 5, 'name': 'G', 'kind': 'auto', 'createdAtUtc': at}
        : {
            'id': 42,
            'title': 'T',
            'description': '',
            'type': 'programme',
            'visibility': 'public',
            'venueId': 1,
            'startTimeUtc': at,
            'endTimeUtc': at,
            'createdAtUtc': at,
            'updatedAtUtc': at,
          };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (
    events: RemoteEventSource(store),
    groups: RemoteGroupSource(store),
    sent: sent,
  );
}

Map<String, dynamic> _bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  const three = [Gender.male, Gender.other, Gender.preferNotToSay];
  const threeOnServer = ['male', 'other', 'prefer_not_to_say'];
  final start = DateTime.utc(2027, 1, 4, 10);

  Future<void> createEvent(
    RemoteEventSource events, {
    List<Gender>? genders,
  }) => events.createEvent(
    title: 'T',
    description: '',
    type: EventType.oneOff,
    visibility: Visibility.public,
    venueId: 1,
    startTimeUtc: start,
    endTimeUtc: start.add(const Duration(hours: 1)),
    genders: genders,
  );

  group('Issue 14: event writes send genders', () {
    test('Issue 14: create sends the list', () async {
      final h = _harness();
      await createEvent(h.events, genders: three);
      final body = _bodyOf(h.sent.single);
      expect(body['genders'], threeOnServer);
      expect(body.containsKey('gender'), isFalse);
    });

    test('Issue 14: create without a criterion sends no genders', () async {
      final h = _harness();
      await createEvent(h.events);
      expect(_bodyOf(h.sent.single).containsKey('genders'), isFalse);
    });

    test('Issue 14: update sends the list, an empty list to clear, and '
        'nothing when left out', () async {
      final h = _harness();
      await h.events.updateEvent(42, version: 1, genders: () => three);
      await h.events.updateEvent(42, version: 1, genders: () => const []);
      await h.events.updateEvent(42, version: 1, title: 'T2');
      expect(_bodyOf(h.sent[0])['genders'], threeOnServer);
      expect(_bodyOf(h.sent[1])['genders'], isEmpty);
      expect(_bodyOf(h.sent[2]).containsKey('genders'), isFalse);
    });

    test('Issue 14: correction sends the list', () async {
      final h = _harness();
      await h.events.correctionOnEvent(42, version: 1, genders: () => three);
      expect(_bodyOf(h.sent.single)['genders'], threeOnServer);
    });
  });

  group('Issue 14: group writes send genders', () {
    test('Issue 14: create sends the list', () async {
      final h = _harness();
      await h.groups.createGroup(name: 'G', genders: three);
      final body = _bodyOf(h.sent.single);
      expect(body['genders'], threeOnServer);
      expect(body.containsKey('gender'), isFalse);
    });

    test('Issue 14: update sends the list, an empty list to clear, and '
        'nothing when left out', () async {
      final h = _harness();
      await h.groups.updateGroup(5, genders: () => three);
      await h.groups.updateGroup(5, genders: () => const []);
      await h.groups.updateGroup(5, name: 'G2');
      expect(_bodyOf(h.sent[0])['genders'], threeOnServer);
      expect(_bodyOf(h.sent[1])['genders'], isEmpty);
      expect(_bodyOf(h.sent[2]).containsKey('genders'), isFalse);
    });
  });

  // The deprecated `gender` parameter is gone (#39): called through
  // `dynamic`, the named argument no longer exists.
  group('Issue 39: writes take no single gender', () {
    test('Issue 39: createEvent takes no gender', () {
      final h = _harness();
      expect(
        () => (h.events as dynamic).createEvent(
          title: 'T',
          description: '',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: 1,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          gender: Gender.male,
        ),
        throwsNoSuchMethodError,
      );
      expect(h.sent, isEmpty);
    });

    test('Issue 39: updateEvent takes no gender', () {
      final h = _harness();
      expect(
        () => (h.events as dynamic).updateEvent(
          42,
          version: 1,
          gender: () => Gender.male,
        ),
        throwsNoSuchMethodError,
      );
      expect(h.sent, isEmpty);
    });

    test('Issue 39: correctionOnEvent takes no gender', () {
      final h = _harness();
      expect(
        () => (h.events as dynamic).correctionOnEvent(
          42,
          version: 1,
          gender: () => Gender.male,
        ),
        throwsNoSuchMethodError,
      );
      expect(h.sent, isEmpty);
    });

    test('Issue 39: createGroup takes no gender', () {
      final h = _harness();
      expect(
        () => (h.groups as dynamic).createGroup(
          name: 'G',
          gender: Gender.male,
        ),
        throwsNoSuchMethodError,
      );
      expect(h.sent, isEmpty);
    });

    test('Issue 39: updateGroup takes no gender', () {
      final h = _harness();
      expect(
        () => (h.groups as dynamic).updateGroup(5, gender: () => Gender.male),
        throwsNoSuchMethodError,
      );
      expect(h.sent, isEmpty);
    });
  });
}
