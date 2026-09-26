import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/my_events_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 43: with no record the server answers 200 `null`. That is "no
/// attendance", not an outage; and a real error must reach the caller rather
/// than read as "no attendance".
void main() {
  final occurrence = DateTime.utc(2026, 9, 1, 18);
  late int unreachableCalls;

  setUp(() => unreachableCalls = 0);

  RemoteMyEventsSource sourceWith(http.Response response) =>
      RemoteMyEventsSource(
        RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient((_) async => response),
          maxRetries: 0,
          onServerUnreachable: () => unreachableCalls++,
        ),
      );

  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Issue 43: no record (200 null) returns null and the server stays '
      'reachable', () async {
    final source = sourceWith(json(null, 200));

    expect(
      await source.getMyOccurrenceAttendance('joe', 1, occurrence),
      isNull,
    );
    expect(unreachableCalls, 0);
  });

  test('Issue 43: a record is returned', () async {
    final source = sourceWith(
      json({
        'id': 7,
        'occurrenceTimeUtc': occurrence.millisecondsSinceEpoch,
        'membername': 'joe',
        'status': 'present',
        'recordedAtUtc': occurrence.millisecondsSinceEpoch,
      }, 200),
    );

    final record = await source.getMyOccurrenceAttendance(
      'joe',
      1,
      occurrence,
    );
    expect(record?.status, AttendanceStatus.present);
  });

  for (final status in [401, 403, 500]) {
    test('Issue 43: a $status reaches the caller', () async {
      final source = sourceWith(
        json({
          'detail': {'code': 'E$status', 'message': 'e'},
        }, status),
      );

      await expectLater(
        source.getMyOccurrenceAttendance('joe', 1, occurrence),
        throwsA(isA<ServerException>().having((e) => e.statusCode, '', status)),
      );
    });
  }
}
