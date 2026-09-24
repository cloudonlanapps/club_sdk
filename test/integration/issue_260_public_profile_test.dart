import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Integration tests for the `/public` profile API + `UserInfoResponse`
/// public fields (flutter #260, server #262).
///
/// - `PublicSource.getPublicProfile` / `listPublicStaff` are reachable
///   **without authentication** and expose only privacy-safe data keyed by
///   the HMAC `publicId`.
/// - Only surfaced coaches (active + coach role + `displayOrder` set) are
///   publicly resolvable; others 404.
/// - `getUserInfo` carries `publicId` + `isPublicProfile` so the app can
///   translate a coach username into the public profile link.
void main() {
  group('Issue 260: public profile API', () {
    late SecureClient admin;
    late SecureClient publicClient; // never logs in

    const surfaced = 'test_pubcoach_surfaced';
    const hidden = 'test_pubcoach_hidden';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      publicClient = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);

      // A public coach: active, coach role, opted into a public profile by
      // the coach themselves (admins can't set is_public_profile).
      await admin.users.createUser(
        username: surfaced,
        email: 'pubcoach_surfaced@test.com',
        passwordHash: 'hash123',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(1990),
        gender: Gender.male,
        firstName: 'Surfaced',
        lastName: 'Coach',
        bio: 'Loves hockey.',
        achievements: 'National champion.',
      );
      await admin.users.approveUser(surfaced);
      await admin.users.assignRole(surfaced, 'coach');
      final coachClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await coachClient.auth.login(surfaced, 'hash123');
      await coachClient.users.updateUser(
        surfaced,
        useNamePublicly: true,
        isPublicProfile: true,
      );
      await coachClient.auth.logout();

      // A coach who has NOT opted in — not publicly resolvable.
      await admin.users.createUser(
        username: hidden,
        email: 'pubcoach_hidden@test.com',
        passwordHash: 'hash123',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(1990),
        gender: Gender.male,
        firstName: 'Hidden',
        lastName: 'Coach',
      );
      await admin.users.approveUser(hidden);
      await admin.users.assignRole(hidden, 'coach');
    });

    test('Issue 260: getUserInfo exposes publicId + isPublicProfile', () async {
      final s = await admin.users.getUserInfo(surfaced);
      expect(s.publicId, isNotEmpty);
      expect(s.publicId, isNot(surfaced)); // HMAC, not the username
      expect(s.isPublicProfile, isTrue);

      final h = await admin.users.getUserInfo(hidden);
      expect(h.publicId, isNotEmpty);
      expect(h.isPublicProfile, isFalse);
    });

    test(
      'Issue 260: anonymous getPublicProfile returns surfaced coach',
      () async {
        final publicId = (await admin.users.getUserInfo(surfaced)).publicId;

        // publicClient has never authenticated.
        final profile = await publicClient.public.getPublicProfile(publicId);
        expect(profile.publicId, publicId);
        expect(profile.displayName, 'Surfaced Coach');
        expect(profile.bio, 'Loves hockey.');
        expect(profile.achievements, 'National champion.');
      },
    );

    test('Issue 260: non-surfaced coach is not publicly resolvable', () async {
      final publicId = (await admin.users.getUserInfo(hidden)).publicId;
      expect(
        () => publicClient.public.getPublicProfile(publicId),
        throwsA(isA<ServerException>()),
      );
    });

    test('Issue 260: unknown publicId returns a server error', () async {
      expect(
        () => publicClient.public.getPublicProfile('not-a-real-id'),
        throwsA(isA<ServerException>()),
      );
    });

    test('Issue 260: listPublicStaff includes the surfaced coach', () async {
      final staff = await publicClient.public.listPublicStaff();
      final surfacedId = (await admin.users.getUserInfo(surfaced)).publicId;
      final hiddenId = (await admin.users.getUserInfo(hidden)).publicId;
      final ids = staff.map((p) => p.publicId).toList();
      expect(ids, contains(surfacedId));
      expect(ids, isNot(contains(hiddenId)));
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });
  });
}
