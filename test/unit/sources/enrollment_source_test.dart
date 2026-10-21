import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// RemoteEnrollmentSource request and response handling, via MockClient.
void main() {
  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<SecureClient> clientAnswering(Map<String, dynamic> body) {
    final store = RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: MockClient((_) async => json(body, 200)),
    );
    return createRemoteSecureClient(
      baseUrl: 'https://example.test/v1',
      store: store,
    );
  }

  group('Issue 31 (R5): listEnrollments must not invent a status', () {
    test(
      'Issue 31: an unknown wire status is not reported as rejected',
      () async {
        final client = await clientAnswering({
          'enrollments': {'alice': 'waitlisted'},
        });
        // Same outcome as Enrollment.fromMap on an unknown status.
        // Actual today: returns {'alice': EnrollmentStatus.rejected}.
        await expectLater(
          client.enrollments.listEnrollments(1),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Issue 31: known wire statuses are read as they are', () async {
      final client = await clientAnswering({
        'enrollments': {'alice': 'accepted', 'bob': 'assignedTrial'},
      });
      expect(await client.enrollments.listEnrollments(1), {
        'alice': EnrollmentStatus.accepted,
        'bob': EnrollmentStatus.assignedTrial,
      });
    });
  });

  group('Issue 38: the per-member enrollment route', () {
    const memberRoute = '/v1/myevents/by_id/alice/7/enrollments';
    final aliceRecord = {
      'id': 1,
      'membername': 'alice',
      'eventId': 7,
      'status': 'accepted',
      'createdAtUtc': 0,
    };
    final notFound = json({
      'detail': {'code': 'ENROLLMENT_NOT_FOUND', 'message': 'not found'},
    }, 404);

    // A stub server that answers only the per-member route and records every
    // path asked for. The roster route (/events/by_id/7/enrollments) is a 500
    // so a fallback to it shows up as a failure.
    Future<(SecureClient, List<String>)> server(http.Response member) async {
      final paths = <String>[];
      final store = RemoteStore(
        baseUrl: 'https://example.test/v1',
        maxRetries: 0,
        client: MockClient((request) async {
          paths.add(request.url.path);
          return request.url.path == memberRoute
              ? member
              : json({'detail': 'roster not expected'}, 500);
        }),
      );
      final client = await createRemoteSecureClient(
        baseUrl: 'https://example.test/v1',
        store: store,
      );
      return (client, paths);
    }

    group('getEnrollment reads the per-member route', () {
      test('Issue 38: returns the record', () async {
        final (client, paths) = await server(json(aliceRecord, 200));
        final enrollment = await client.enrollments.getEnrollment(7, 'alice');
        expect(enrollment.status, EnrollmentStatus.accepted);
        expect(paths, [memberRoute]);
      });

      test('Issue 38: a missing enrollment is ENROLLMENT_NOT_FOUND', () async {
        final (client, _) = await server(notFound);
        await expectLater(
          client.enrollments.getEnrollment(7, 'alice'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.enrollmentNotFound,
            ),
          ),
        );
      });
    });

    group('getEnrollmentStatus asks for one member, not the roster', () {
      test('Issue 38: returns the status from one small request', () async {
        final (client, paths) = await server(json(aliceRecord, 200));
        expect(
          await client.enrollments.getEnrollmentStatus(7, 'alice'),
          EnrollmentStatus.accepted,
        );
        expect(paths, [memberRoute]);
      });

      test('Issue 38: no enrollment is null', () async {
        final (client, _) = await server(notFound);
        expect(
          await client.enrollments.getEnrollmentStatus(7, 'alice'),
          isNull,
        );
      });

      test('Issue 38: any other error propagates', () async {
        final (client, _) = await server(
          json({
            'detail': {
              'code': SdkErrorCode.insufficientPermission,
              'message': 'no',
            },
          }, 403),
        );
        await expectLater(
          client.enrollments.getEnrollmentStatus(7, 'alice'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 403)
                .having(
                  (e) => e.code,
                  'code',
                  SdkErrorCode.insufficientPermission,
                ),
          ),
        );
      });
    });
  });
}
