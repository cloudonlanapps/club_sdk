import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 30: `GET /users/count` (club_server#308, #362).
void main() {
  group('Issue 30: user counts', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test('Issue 30: every status is present and total is their sum', () async {
      final counts = await client.users.getUserCounts();
      expect(counts.byStatus.keys, containsAll(UserStatus.values));
      final sum = UserStatus.values.map(counts.of).fold(0, (a, b) => a + b);
      expect(counts.total, sum);
      // The seed data creates active and pending users.
      expect(counts.of(UserStatus.active), greaterThan(0));
      expect(counts.of(UserStatus.pending), greaterThan(0));
    });

    test(
      // A sign-up lands in registered, or in pending when the stack has
      // identity verification off (#2).
      'Issue 30: a sign-up joins its status bucket',
      () async {
        final bucket = signUpStatus(await stackCapabilities(client));
        final before = await client.users.getUserCounts();
        final other = await createRemoteSecureClient(baseUrl: baseUrl);
        await other.auth.register(
          username: 'test_issue30_registered',
          email: 'test_issue30_registered@example.com',
          password: 'password123',
          phone: '9000000030',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Thirty',
          lastName: 'Issue',
        );
        final after = await client.users.getUserCounts();
        expect(after.of(bucket), before.of(bucket) + 1);
        expect(after.total, before.total + 1);
      },
    );

    test('Issue 30: a coach may read the counts', () async {
      final coach = await createRemoteSecureClient(baseUrl: baseUrl);
      await coach.auth.login('test_coach_1', 'password123');
      final counts = await coach.users.getUserCounts();
      expect(counts.total, greaterThan(0));
      await coach.auth.logout();
    });
  });
}
