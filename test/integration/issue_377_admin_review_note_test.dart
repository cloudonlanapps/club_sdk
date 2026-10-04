import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue #377 — `UserPrivate.adminReviewNote`.
///
/// SDK field maps 1:1 to server #123. The field is surfaced on
/// `UserPrivateResponse` only (private/admin reads of a single user) and
/// **must not** appear on the public list response (`UserInfoResponse`).
void main() {
  group('Issue 377: UserPrivate.adminReviewNote', () {
    late SecureClient adminClient;
    // The review lifecycle below exists only while identity verification is
    // on (#2); with it off, register lands users at pending and
    // issue_2_identity_verification_test covers that flow instead.
    late bool verificationOn;
    late String adminAccessToken;
    const password = 'password123';

    var userCounter = 0;
    String nextUsername(String tag) {
      userCounter += 1;
      return 'test_377_${tag}_$userCounter';
    }

    Future<String> registerFresh(String tag) async {
      final username = nextUsername(tag);
      await adminClient.auth.register(
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: username,
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(1995, 6, 15),
      );
      return username;
    }

    Future<SecureClient> loginAs(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      await c.auth.login(username, password);
      return c;
    }

    /// Raw HTTP GET against the API using the admin token so we can inspect
    /// the JSON payload key-set directly — the SDK's typed [UserInfo] /
    /// [UserPrivate] models silently drop unknown keys, so a SDK-level
    /// readback cannot prove the server omits the field.
    Future<Map<String, dynamic>> rawGet(String path) async {
      final uri = Uri.parse('$baseUrl$path');
      final resp = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $adminAccessToken',
        },
      );
      expect(resp.statusCode, 200, reason: 'GET $path returned ${resp.body}');
      return json.decode(resp.body) as Map<String, dynamic>;
    }

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      final token = await adminClient.auth.login(sudoUsername, sudoPassword);
      verificationOn = (await stackCapabilities(
        adminClient,
      )).identityVerification;
      adminAccessToken = token.accessToken;
    });

    tearDownAll(() async {
      try {
        await adminClient.auth.logout();
      } on Exception {
        /* ignore */
      }
    });

    test(
      'Issue 377: fresh registered user with no active review row has '
      'adminReviewNote == null',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('fresh');
        final userClient = await loginAs(username);

        final me = await userClient.auth.getCurrentUser();
        expect(me.status, UserStatus.registered);
        expect(me.adminReviewNote, isNull);

        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);
        expect(readback.adminReviewNote, isNull);
      },
    );

    test(
      'Issue 377: after reconsiderUser, adminReviewNote == reason (status '
      'stays registered)',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('reconsider');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        await adminClient.users.reconsiderUser(username, 'fix DOB');

        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);
        expect(readback.adminReviewNote, 'fix DOB');

        // Self-read also sees the note (it lives on UserPrivateResponse).
        final me = await userClient.auth.getCurrentUser();
        expect(me.adminReviewNote, 'fix DOB');
      },
    );

    test(
      'Issue 377: after reapply closes the row, adminReviewNote == null '
      '(status still registered)',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('reapply');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();
        await adminClient.users.reconsiderUser(username, 'fix DOB');

        // Sanity: note is present before reapply.
        var readback = await adminClient.users.getUserPrivate(username);
        expect(readback.adminReviewNote, 'fix DOB');

        await userClient.users.reapply(
          username,
          dateOfBirthUtc: DateTime.utc(1990, 1, 2),
        );

        readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);
        expect(readback.adminReviewNote, isNull);
      },
    );

    test(
      'Issue 377: user with status == active has adminReviewNote == null '
      '(server short-circuits regardless of any historical review rows)',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('active');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);

        // Build a historical review row, then approve. The server should
        // short-circuit on status != registered and return no note.
        await userClient.users.submitForReview();
        await adminClient.users.reconsiderUser(username, 'historical note');
        await userClient.users.reapply(username, firstName: 'NewFirst');
        await userClient.users.submitForReview();
        await adminClient.users.approveUser(
          username,
          resolutionReason: 'looks good',
        );

        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.active);
        expect(readback.adminReviewNote, isNull);
      },
    );

    test(
      'Issue 377 privacy invariant: list endpoint payload (UserInfoResponse) '
      'does not surface adminReviewNote, even for users with an active '
      'review row',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('listprivacy');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();
        await adminClient.users.reconsiderUser(username, 'leak check');

        // Sanity: private readback does carry the note.
        final priv = await adminClient.users.getUserPrivate(username);
        expect(priv.adminReviewNote, 'leak check');

        // Now hit the list endpoint raw and assert the key is absent on
        // *every* item, including this user's entry.
        final body = await rawGet('/users?limit=100');
        final items = body['items'] as List<dynamic>;
        expect(items, isNotEmpty);
        for (final entry in items) {
          final map = entry as Map<String, dynamic>;
          expect(
            map.containsKey('adminReviewNote'),
            isFalse,
            reason:
                'list entry for ${map['username']} must not surface '
                'adminReviewNote (privacy invariant)',
          );
        }

        // The single-user public endpoint (UserInfoResponse) also must not
        // surface it.
        final single = await rawGet('/users/by_id/$username');
        expect(single.containsKey('adminReviewNote'), isFalse);

        // And the private endpoint *does* surface it — proves the assertion
        // above is meaningful, not vacuous.
        final privateRaw = await rawGet('/users/by_id/$username/private');
        expect(privateRaw['adminReviewNote'], 'leak check');
      },
    );
  });
}
