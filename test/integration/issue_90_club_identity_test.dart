import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 90: the `club_info` preference, typed as [ClubIdentity].
///
/// The super admin writes it through `setClubIdentity`; it reads back through
/// `getClubIdentity` and the public club-info read, keys the model does not
/// know survive an edit, and nobody else may write it. The original document
/// is restored afterwards.
void main() {
  group('Issue 90: club identity', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    late SecureClient anon;
    late Object? original;

    const identity = ClubIdentity(
      name: 'My Example Club',
      shortName: 'MEC',
      inquiryEmail: 'inquiries@myexampleclub.com',
      contact: ClubContactDetails(
        phoneNumber: '+911234567890',
        email: 'hello@myexampleclub.com',
        tagline: LocalizedText('Skate with us', {'mr': 'आमच्यासोबत स्केट करा'}),
        address: LocalizedText('1 Rink Road'),
        postalCode: '400001',
        instagramUrl: 'https://instagram.com/myexampleclub',
      ),
    );

    Future<void> register(String username) => registerAndApprove(
      client: sudo,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: 'password123',
      firstName: username,
      phone: '0000000000',
      dateOfBirthUtc: DateTime.utc(2000),
      gender: Gender.male,
    );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);
      original = (await sudo.admin.getPreference(
        ClubIdentity.preferenceKey,
      )).value;

      await register('test_i90_admin');
      await sudo.users.assignRole('test_i90_admin', 'admin');
      await register('test_i90_member');

      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login('test_i90_admin', 'password123');
      expect((await admin.auth.getCurrentUser()).roles.isAdmin, isTrue);

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login('test_i90_member', 'password123');
      expect(
        (await member.auth.getCurrentUser()).username,
        'test_i90_member',
      );

      anon = await createRemoteSecureClient(baseUrl: baseUrl);
    });

    tearDownAll(() async {
      // A never-written club_info reads as null, which the server will not
      // store; an empty object reads the same through the public read.
      await sudo.admin.setPreference(
        ClubIdentity.preferenceKey,
        original ?? const <String, dynamic>{},
      );
      await admin.auth.logout();
      await member.auth.logout();
      await sudo.auth.logout();
    });

    test('Issue 90: the super admin writes the identity and reads it '
        'back', () async {
      final written = await sudo.admin.setClubIdentity(identity);
      expect(written, identity);

      final read = await sudo.admin.getClubIdentity();
      expect(read, identity);
      expect(read.contact!.tagline!.resolve('mr'), 'आमच्यासोबत स्केट करा');
    });

    test('Issue 90: the public club-info read carries the same '
        'identity', () async {
      await sudo.admin.setClubIdentity(identity);

      final info = await anon.public.getPublicClubInfo();
      expect(info.identity, identity);
    });

    test('Issue 90: an edit keeps the keys the model does not read', () async {
      await sudo.admin.setPreference(ClubIdentity.preferenceKey, {
        ...identity.toMap(),
        'story': {'default': 'Founded on a frozen pond.'},
      });

      final read = await sudo.admin.getClubIdentity();
      expect(read.extra, {
        'story': {'default': 'Founded on a frozen pond.'},
      });
      await sudo.admin.setClubIdentity(read.copyWith(shortName: () => 'Club'));

      final stored = await sudo.admin.getPreference(
        ClubIdentity.preferenceKey,
      );
      final value = stored.value! as Map<String, dynamic>;
      expect(value['shortName'], 'Club');
      expect(value['name'], 'My Example Club');
      expect(value['story'], {'default': 'Founded on a frozen pond.'});
    });

    test('Issue 90: a regular admin may not read or write the '
        'identity', () async {
      await expectLater(
        admin.admin.getClubIdentity(),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        admin.admin.setClubIdentity(identity),
        throwsA(isA<ServerException>()),
      );
    });

    test('Issue 90: a member may not read or write the identity', () async {
      await expectLater(
        member.admin.getClubIdentity(),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        member.admin.setClubIdentity(identity),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
