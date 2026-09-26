import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/auth_source.dart';
import 'package:club_sdk_2/remote_store/sources/evaluation_source.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/remote_store/sources/notification_source.dart';
import 'package:club_sdk_2/remote_store/sources/public_source.dart';
import 'package:club_sdk_2/remote_store/sources/user_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Source-level fixes from the SDK review: #45, #46, #47, #48, #51, #52, #53.
void main() {
  late List<http.Request> requests;

  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response error(int status, String code) => json({
    'detail': {'code': code, 'message': code},
  }, status);

  RemoteStore storeWith(http.Response Function(http.Request) respond) {
    requests = [];
    return RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
      maxRetries: 0,
    );
  }

  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  final eventJson = {
    'id': 42,
    'title': 'T',
    'description': 'D',
    'type': 'camp',
    'visibility': 'public',
    'venueId': 1,
    'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
    'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
    'createdAtUtc': DateTime.utc(2026, 1, 1, 9).millisecondsSinceEpoch,
    'updatedAtUtc': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
    'isFeatured': false,
  };

  group('Issue 45: logout always signs the client out locally', () {
    for (final (status, code) in [
      (403, 'ACCOUNT_NOT_ACTIVE'),
      (401, 'INVALID_TOKEN'),
    ]) {
      test('a $status $code refusal clears the token and does not '
          'throw', () async {
        final store = storeWith((_) => error(status, code))..authToken = 'tok';

        await RemoteAuthSource(store).logout();

        expect(store.authToken, isNull);
        expect(requests, hasLength(1));
      });
    }

    test('any other failure clears the token and still throws', () async {
      final store = storeWith((_) => error(500, 'INTERNAL_ERROR'))
        ..authToken = 'tok';

      await expectLater(
        RemoteAuthSource(store).logout(),
        throwsA(isA<ServerException>()),
      );
      expect(store.authToken, isNull);
    });

    test('a successful logout clears the token', () async {
      final store = storeWith((_) => http.Response('', 204))..authToken = 'tok';

      await RemoteAuthSource(store).logout();

      expect(store.authToken, isNull);
    });
  });

  group('Issue 46: template categories are sent without their id', () {
    const fetched = [
      EvaluationCategory(
        id: 7,
        key: 'skating',
        label: 'S',
        minValue: 1,
        maxValue: 5,
      ),
      EvaluationCategory(
        id: 8,
        key: 'passing',
        label: 'P',
        minValue: 1,
        maxValue: 5,
      ),
    ];

    test('EvaluationCategory.toInputMap has no id', () {
      expect(fetched.first.toInputMap(), {
        'key': 'skating',
        'label': 'S',
        'minValue': 1,
        'maxValue': 5,
        'defaultValue': null,
      });
    });

    test('updateTemplate with fetched categories sends no id', () async {
      final store = storeWith((_) => error(418, 'STOP'));
      await expectLater(
        RemoteEvaluationSource(store).updateTemplate(3, categories: fetched),
        throwsA(isA<ServerException>()),
      );
      final categories = bodyOf(requests.single)['categories'] as List;
      expect(
        categories.cast<Map<String, dynamic>>().map((c) => c.containsKey('id')),
        everyElement(isFalse),
      );
    });

    test('createTemplate with fetched categories sends no id', () async {
      final store = storeWith((_) => error(418, 'STOP'));
      await expectLater(
        RemoteEvaluationSource(store).createTemplate(
          name: 'copy',
          scopes: const [EvaluationScopeType.event],
          categories: fetched,
        ),
        throwsA(isA<ServerException>()),
      );
      final categories = bodyOf(requests.single)['categories'] as List;
      expect(
        categories.cast<Map<String, dynamic>>().map((c) => c.containsKey('id')),
        everyElement(isFalse),
      );
    });
  });

  group('Issue 47: listPublicEventMarketing', () {
    test('an empty list returns {} without a request', () async {
      final store = storeWith((_) => error(422, 'VALIDATION_ERROR'));

      expect(
        await RemotePublicSource(store).listPublicEventMarketing([]),
        isEmpty,
      );
      expect(requests, isEmpty);
    });
  });

  group('Issue 48: updateEvent clears coaches', () {
    test('coachNames: () => null sends an empty list', () async {
      final store = storeWith((_) => json(eventJson, 200));

      await RemoteEventSource(store).updateEvent(
        42,
        version: 1,
        coachNames: () => null,
      );

      expect(bodyOf(requests.single)['coachNames'], <String>[]);
    });

    test('updateEventForAllFuture: coachNames: () => null sends an empty '
        'list', () async {
      final store = storeWith((_) => json(eventJson, 200));

      await RemoteEventSource(store).updateEventForAllFuture(
        42,
        version: 1,
        effectiveDateTimeUtc: DateTime.utc(2027, 2),
        coachNames: () => null,
      );

      expect(bodyOf(requests.single)['coachNames'], <String>[]);
    });

    test('an omitted coachNames is not sent', () async {
      final store = storeWith((_) => json(eventJson, 200));

      await RemoteEventSource(store).updateEvent(42, version: 1, title: 'x');

      expect(bodyOf(requests.single).containsKey('coachNames'), isFalse);
    });
  });

  group('Issue 51: listDeletedEvents is paginated', () {
    test('returns items and total, sending offset and limit', () async {
      final store = storeWith(
        (_) => json({
          'items': [eventJson],
          'total': 31,
          'offset': 20,
          'limit': 10,
        }, 200),
      );

      final page = await RemoteEventSource(store).listDeletedEvents(
        offset: 20,
        limit: 10,
      );

      expect(page.items.single.id, 42);
      expect(page.total, 31);
      expect(requests.single.url.queryParameters, {
        'offset': '20',
        'limit': '10',
      });
    });
  });

  group('Issue 52: getDeletedUsers search and sort', () {
    test('sends searchTerm, sortBy and descending', () async {
      final store = storeWith(
        (_) => json({
          'items': <Object>[],
          'total': 0,
          'offset': 0,
          'limit': 20,
        }, 200),
      );

      await RemoteUserSource(store).getDeletedUsers(
        searchTerm: 'ann',
        sortBy: 'username',
        descending: true,
      );

      expect(requests.single.url.queryParameters, {
        'offset': '0',
        'limit': '20',
        'searchTerm': 'ann',
        'sortBy': 'username',
        'descending': 'true',
      });
    });
  });

  group('Issue 53: createNotification sends pendingActionKey', () {
    Future<Map<String, dynamic>> send({String? key}) async {
      final store = storeWith((_) => error(418, 'STOP'));
      await expectLater(
        RemoteNotificationSource(store).createNotification(
          username: 'joe',
          type: 'x.y',
          channel: 'inApp',
          payload: const {},
          pendingActionKey: key,
        ),
        throwsA(isA<ServerException>()),
      );
      return bodyOf(requests.single);
    }

    test('when set', () async {
      expect((await send(key: 'leave:1:2'))['pendingActionKey'], 'leave:1:2');
    });

    test('not when unset', () async {
      expect((await send()).containsKey('pendingActionKey'), isFalse);
    });
  });
}
