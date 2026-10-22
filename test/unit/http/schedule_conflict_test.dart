import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/remote_store/sources/occurrence_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 56: a schedule write that clashes answers 409 `SCHEDULE_CONFLICT`
/// with the full conflict report (club_server#72). The SDK raises it as
/// [ScheduleConflictException] carrying the parsed [ConflictReport].
Map<String, dynamic> pair(int ts, int te, int os, int oe) => {
  'targetStartUtc': ts,
  'targetEndUtc': te,
  'otherStartUtc': os,
  'otherEndUtc': oe,
};

Map<String, dynamic> item(int id, String title, String type) => {
  'eventId': id,
  'eventTitle': title,
  'eventType': type,
  'occurrences': [pair(1000, 2000, 1500, 2500)],
};

/// The server's 409 body: `{detail: {code, message, venueConflicts,
/// organizerConflicts, coachConflicts}}`.
Map<String, dynamic> conflictBody({
  List<Map<String, dynamic>> venue = const [],
  List<Map<String, dynamic>> organizer = const [],
  List<Map<String, dynamic>> coach = const [],
}) => {
  'detail': {
    'code': 'SCHEDULE_CONFLICT',
    'message': 'The schedule clashes with other events',
    'venueConflicts': venue,
    'organizerConflicts': organizer,
    'coachConflicts': coach,
  },
};

RemoteStore storeAnswering(Map<String, dynamic> body) {
  final client = MockClient(
    (request) async => http.Response(
      jsonEncode(body),
      409,
      headers: {'content-type': 'application/json'},
    ),
  );
  return RemoteStore(baseUrl: 'https://example.test/v1', client: client);
}

void main() {
  group('Issue 56: 409 SCHEDULE_CONFLICT mapping', () {
    test('Issue 56: maps to ScheduleConflictException', () {
      final exc = mapHttpError(
        409,
        conflictBody(venue: [item(3, 'V', 'camp')]),
      );
      expect(exc, isA<ScheduleConflictException>());
      expect(exc.statusCode, 409);
      expect(exc.code, SdkErrorCode.scheduleConflict);
      expect(exc.message, 'The schedule clashes with other events');
    });

    test('Issue 56: the report keeps every gate with its pairs', () {
      final exc =
          mapHttpError(
                409,
                conflictBody(
                  venue: [item(3, 'At the rink', 'programme')],
                  organizer: [item(4, 'Same organizer', 'oneOff')],
                  coach: [item(5, 'Same coach', 'camp')],
                ),
              )
              as ScheduleConflictException;
      final report = exc.report;
      expect(report.hasConflict, isTrue);
      expect(report.venueConflicts.single.eventId, 3);
      expect(report.venueConflicts.single.eventType, 'programme');
      expect(report.organizerConflicts.single.eventTitle, 'Same organizer');
      expect(report.coachConflicts.single.eventId, 5);
      expect(
        report.coachConflicts.single.occurrences.single,
        OccurrencePair.fromMap(pair(1000, 2000, 1500, 2500)),
      );
    });

    test('Issue 56: a coach-only clash carries the coach conflict', () {
      final exc =
          mapHttpError(409, conflictBody(coach: [item(7, 'Coach', 'oneOff')]))
              as ScheduleConflictException;
      expect(exc.report.venueConflicts, isEmpty);
      expect(exc.report.organizerConflicts, isEmpty);
      expect(exc.report.coachConflicts.single.eventId, 7);
    });

    test('Issue 56: the report is also left in details', () {
      final exc = mapHttpError(
        409,
        conflictBody(coach: [item(7, 'C', 'camp')]),
      );
      expect(exc.details?['coachConflicts'], hasLength(1));
    });

    test('Issue 56: TIME_CONFLICT (member gate) stays a ServerException', () {
      final exc = mapHttpError(409, const {
        'detail': {'code': 'TIME_CONFLICT', 'message': 'm'},
      });
      expect(exc, isNot(isA<ScheduleConflictException>()));
      expect(exc.code, SdkErrorCode.timeConflict);
    });

    test(
      'Issue 56: a codeless hasConflict body is no longer TIME_CONFLICT',
      () {
        // club_server#72 removed the old programme 409 body; nothing infers a
        // code from it any more.
        final exc = mapHttpError(409, const {
          'detail': {'hasConflict': true, 'venueConflicts': <Object>[]},
        });
        expect(exc.code, isNot(SdkErrorCode.timeConflict));
        expect(exc, isNot(isA<ScheduleConflictException>()));
      },
    );
  });

  group('Issue 56: writes raise ScheduleConflictException', () {
    final body = conflictBody(coach: [item(9, 'Busy coach', 'programme')]);
    final start = DateTime.utc(2027, 1, 1, 10);

    test('Issue 56: createEvent raises it with the report', () async {
      final source = RemoteEventSource(storeAnswering(body));
      await expectLater(
        source.createEvent(
          title: 'T',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: 1,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        ),
        throwsA(
          isA<ScheduleConflictException>().having(
            (e) => e.report.coachConflicts.single.eventId,
            'coach conflict',
            9,
          ),
        ),
      );
    });

    test('Issue 56: rescheduleOccurrence raises it with the report', () async {
      final source = RemoteOccurrenceSource(storeAnswering(body));
      await expectLater(
        source.rescheduleOccurrence(
          1,
          start,
          version: 1,
          newStartTimeUtc: start.add(const Duration(hours: 2)),
        ),
        throwsA(
          isA<ScheduleConflictException>().having(
            (e) => e.report.coachConflicts.single.eventTitle,
            'coach conflict',
            'Busy coach',
          ),
        ),
      );
    });
  });
}
