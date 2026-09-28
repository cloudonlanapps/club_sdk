import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_sdk#83 (club_server#511, #512): a direct notification to a user who
/// may not receive it is refused with 422 `RECIPIENT_NOT_DELIVERABLE`.
///
/// A user who has left may receive nothing; a blocked user may receive only
/// account notices (`user.role_changed` is one). An active user receives
/// anything.
void main() {
  group('club_sdk#83: a direct notice to an undeliverable recipient', () {
    late SecureClient admin;

    const password = 'password123';
    const left = 'test_i83_left';
    const blocked = 'test_i83_blocked';
    const active = 'test_i83_active';

    final notDeliverable = throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.recipientNotDeliverable),
    );

    Future<AppNotification> send(String username, String type) =>
        admin.notifications.createNotification(
          username: username,
          type: type,
          channel: 'inApp',
          payload: <String, dynamic>{
            'v': 1,
            'type': type,
            'data': <String, dynamic>{'title': 'test_i83 $type'},
          },
        );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);

      for (final username in [left, blocked, active]) {
        await registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: username,
          phone: '0000000083',
          dateOfBirthUtc: DateTime.utc(1995),
          gender: Gender.male,
        );
      }
      await admin.users.markLeft(left);
      await admin.users.blockUser(blocked);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('a notice to a user who has left is refused', () async {
      await expectLater(send(left, 'test.generic'), notDeliverable);
    });

    test('an account notice to a user who has left is refused', () async {
      await expectLater(
        send(left, NotificationType.userRoleChanged),
        notDeliverable,
      );
    });

    test('a club-activity notice to a blocked user is refused', () async {
      await expectLater(
        send(blocked, NotificationType.eventCancelled),
        notDeliverable,
      );
    });

    test('an account notice to a blocked user is delivered', () async {
      final sent = await send(blocked, NotificationType.userRoleChanged);
      expect(sent.username, blocked);
    });

    test('any notice to an active user is delivered', () async {
      final sent = await send(active, NotificationType.eventCancelled);
      expect(sent.username, active);
    });
  });
}
