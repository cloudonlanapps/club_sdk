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
}
