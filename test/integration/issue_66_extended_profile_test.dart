import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 66: the extended profile, the membership date and the club's
/// profile options (club_server#92).
///
/// The profile fields are stored and returned on every stack; the profile
/// options write needs `extended_profile_enabled` (on in
/// `sdk_test_server1.conf`, off in `sdk_test_server2.conf`, #86), so the
/// cases that write options run on `just test` and the 503 on
/// `just test-server2`.
/// Only the super admin writes them (club_server#98, #74).
void main() {
  group('Issue 66: extended profile', () {
    const password = 'password123';
    const memberName = 'test_i66_member';
    const otherName = 'test_i66_other';
    const adminName = 'test_i66_admin';
    const newcomerName = 'test_i66_newcomer';

    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    late SecureClient newcomer;
    late Capabilities capabilities;
    late ProfileOptions originalOptions;

    const options = ProfileOptions(
      positions: [
        ProfilePosition(
          value: 'Forward',
          label: {'en': 'Forward', 'mr': 'फॉरवर्ड'},
        ),
        ProfilePosition(value: 'Goalie', label: {'en': 'Goalie'}),
      ],
      languages: ['English', 'Marathi'],
    );

    Future<void> register(String username) => registerAndApprove(
      client: sudo,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000066',
      dateOfBirthUtc: DateTime.utc(2010, 5, 4),
      gender: Gender.male,
    );

    Future<SecureClient> signIn(String username) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

    Matcher refused(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      capabilities = await sudo.capabilities.getCapabilities();
      originalOptions = await sudo.users.getProfileOptions();

      await register(memberName);
      await register(otherName);
      await register(adminName);
      await sudo.users.assignRole(adminName, 'admin');
      final registered = await sudo.auth.register(
        username: newcomerName,
        email: '$newcomerName@test.com',
        password: password,
        phone: '0000000067',
        dateOfBirthUtc: DateTime.utc(2011, 2, 3),
        gender: Gender.female,
        firstName: newcomerName,
      );
      expect(registered.status, signUpStatus(capabilities));
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);

      admin = await signIn(adminName);
      member = await signIn(memberName);
      newcomer = await signIn(newcomerName);
    });

    tearDownAll(() async {
      if (capabilities.extendedProfile) {
        await sudo.users.setProfileOptions(originalOptions);
      }
      for (final client in [newcomer, member, admin, sudo]) {
        await client.auth.logout();
      }
    });

    // ── Capabilities ─────────────────────────────────────────────────────

    test('Issue 66: the capabilities report extendedProfile, the same '
        'before login', () async {
      final origin = baseUrl.replaceFirst(RegExp(r'/v1$'), '');
      final response = await http.get(Uri.parse('$origin/v1/capabilities'));
      expect(response.statusCode, 200);
      final raw = json.decode(response.body) as Map<String, dynamic>;
      expect(raw['extendedProfile'], isA<bool>());
      expect(raw['extendedProfile'], capabilities.extendedProfile);
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      expect(await anon.capabilities.getCapabilities(), capabilities);
    });

    // ── Self edit ────────────────────────────────────────────────────────

    test('Issue 66: a member sets their own extended fields and reads them '
        'back; an admin sees them', () async {
      const guardian = Guardian(
        name: 'Asha Rao',
        relation: 'Mother',
        phone: '+919800000066',
      );
      final updated = await member.users.updateUser(
        memberName,
        clubDistrict: () => 'Pune District',
        pastExperience: () => 'Two seasons of roller hockey.\nOne camp.',
        nationality: () => 'Indian',
        guardian: () => guardian,
      );
      expect(updated.clubDistrict, 'Pune District');
      expect(updated.guardian, guardian);

      final me = await member.auth.getCurrentUser();
      expect(me.clubDistrict, 'Pune District');
      expect(me.pastExperience, 'Two seasons of roller hockey.\nOne camp.');
      expect(me.nationality, 'Indian');
      expect(me.guardian, guardian);

      final seen = await admin.users.getUserPrivate(memberName);
      expect(seen.clubDistrict, 'Pune District');
      expect(seen.guardian, guardian);
    });

    test(
      'Issue 66: a null clears one extended field and leaves the others',
      () async {
        await member.users.updateUser(
          memberName,
          clubDistrict: () => 'Pune District',
          nationality: () => 'Indian',
        );
        final cleared = await member.users.updateUser(
          memberName,
          nationality: () => null,
        );
        expect(cleared.nationality, isNull);
        expect(cleared.clubDistrict, 'Pune District');
        final readBack = await member.users.getUserPrivate(memberName);
        expect(readBack.nationality, isNull);
        expect(readBack.clubDistrict, 'Pune District');
      },
    );

    test('Issue 66: a guardian phone over 20 characters is refused', () async {
      await expectLater(
        member.users.updateUser(
          memberName,
          guardian: () => const Guardian(phone: '+91 98000 00000 00000'),
        ),
        refused(422, SdkErrorCode.validationError),
      );
    });

    test(
      "Issue 66: a member may not edit another member's extended fields",
      () async {
        await expectLater(
          member.users.updateUser(otherName, nationality: () => 'Indian'),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final other = await admin.users.getUserPrivate(otherName);
        expect(other.nationality, isNull);
      },
    );

    test(
      'Issue 66: a user not yet approved sets their own extended fields',
      () async {
        final updated = await newcomer.users.updateUser(
          newcomerName,
          clubDistrict: () => 'Mumbai District',
          guardian: () => const Guardian(name: 'Ravi', relation: 'Father'),
        );
        expect(updated.status, isNot(UserStatus.active));
        expect(updated.clubDistrict, 'Mumbai District');
        final me = await newcomer.auth.getCurrentUser();
        expect(me.guardian, const Guardian(name: 'Ravi', relation: 'Father'));
      },
    );

    test(
      'Issue 66: a user not yet approved may not send anything else',
      () async {
        await expectLater(
          newcomer.users.updateUser(
            newcomerName,
            nationality: () => 'Indian',
            bio: () => 'Hello',
          ),
          refused(403, SdkErrorCode.accountNotActive),
        );
        final me = await newcomer.auth.getCurrentUser();
        expect(me.nationality, isNull);
        expect(me.bio, isNull);
      },
    );

    // ── Membership date ──────────────────────────────────────────────────

    test('Issue 66: approval gives a member a membership date at UTC '
        'midnight; a newcomer has none', () async {
      final me = await member.auth.getCurrentUser();
      final date = me.membershipDateUtc;
      expect(date, isNotNull);
      expect(date!.isUtc, isTrue);
      expect(date, DateTime.utc(date.year, date.month, date.day));
      expect((await newcomer.auth.getCurrentUser()).membershipDateUtc, isNull);
    });

    test('Issue 66: an admin sets and clears a membership date', () async {
      final date = DateTime.utc(2023, 6, 15);
      final set = await admin.users.updateUser(
        memberName,
        membershipDateUtc: () => date,
      );
      expect(set.membershipDateUtc, date);
      expect((await member.auth.getCurrentUser()).membershipDateUtc, date);

      final cleared = await admin.users.updateUser(
        memberName,
        membershipDateUtc: () => null,
      );
      expect(cleared.membershipDateUtc, isNull);
      expect(
        (await admin.users.getUserPrivate(memberName)).membershipDateUtc,
        isNull,
      );
    });

    test('Issue 66: a member may not set their own membership date', () async {
      final before = (await member.auth.getCurrentUser()).membershipDateUtc;
      await expectLater(
        member.users.updateUser(
          memberName,
          membershipDateUtc: () => DateTime.utc(2020),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.code, 'code', SdkErrorCode.protectedFields)
              .having((e) => e.details?['fields'], 'fields', [
                'membershipDateUtc',
              ]),
        ),
      );
      expect(
        (await member.auth.getCurrentUser()).membershipDateUtc,
        before,
      );
    });

    test(
      'Issue 66: a membership date that is not a UTC midnight is refused',
      () async {
        await expectLater(
          admin.users.updateUser(
            memberName,
            membershipDateUtc: () => DateTime.utc(2023, 6, 15, 10),
          ),
          refused(422, SdkErrorCode.invalidDobNotUtcMidnight),
        );
      },
    );

    // ── Profile options ──────────────────────────────────────────────────

    test('Issue 66: any signed-in user reads the profile options, a newcomer '
        'included; anonymous is refused', () async {
      final read = await member.users.getProfileOptions();
      expect(await newcomer.users.getProfileOptions(), read);
      expect(await admin.users.getProfileOptions(), read);
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      await expectLater(
        anon.users.getProfileOptions(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    });

    test('Issue 74: writing the profile options answers 503 while the '
        'extended profile is off', () async {
      if (skipIf(
        enabled: capabilities.extendedProfile,
        feature: 'extended profile',
      )) {
        return;
      }
      await expectLater(
        sudo.users.setProfileOptions(options),
        throwsModuleDisabled(SdkErrorCode.extendedProfileDisabled),
      );
      expect(await sudo.users.getProfileOptions(), originalOptions);
    });

    test('Issue 74: the super admin writes the profile options and a member '
        'reads them', () async {
      if (skipUnless(
        enabled: capabilities.extendedProfile,
        module: 'extended profile',
      )) {
        return;
      }
      final written = await sudo.users.setProfileOptions(options);
      expect(written, options);
      final read = await member.users.getProfileOptions();
      expect(read, options);
      expect(read.position('Forward')?.labelFor('mr'), 'फॉरवर्ड');
    });

    test('Issue 74: an admin or a member may not write the profile options, '
        'whether the extended profile is on or off', () async {
      final before = await sudo.users.getProfileOptions();
      for (final client in [admin, member]) {
        await expectLater(
          client.users.setProfileOptions(options),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
      }
      expect(await sudo.users.getProfileOptions(), before);
    });

    test(
      'Issue 74: a profile options document with a duplicate is refused',
      () async {
        if (skipUnless(
          enabled: capabilities.extendedProfile,
          module: 'extended profile',
        )) {
          return;
        }
        await expectLater(
          sudo.users.setProfileOptions(
            const ProfileOptions(languages: ['English', 'English']),
          ),
          refused(422, SdkErrorCode.invalidPreferenceValue),
        );
      },
    );

    test('Issue 75: a member picks two positions and two languages from the '
        'club options and reads them back as lists', () async {
      if (skipUnless(
        enabled: capabilities.extendedProfile,
        module: 'extended profile',
      )) {
        return;
      }
      await sudo.users.setProfileOptions(options);
      final updated = await member.users.updateUser(
        memberName,
        preferredPositions: const ['Goalie', 'Forward'],
        preferredLanguages: const ['Marathi', 'English'],
      );
      expect(updated.preferredPositions, ['Goalie', 'Forward']);
      expect(updated.preferredLanguages, ['Marathi', 'English']);
      final me = await member.auth.getCurrentUser();
      expect(me.preferredPositions, ['Goalie', 'Forward']);
      expect(me.preferredLanguages, ['Marathi', 'English']);
      final seen = await admin.users.getUserPrivate(memberName);
      expect(seen.preferredPositions, ['Goalie', 'Forward']);
      expect(seen.preferredLanguages, ['Marathi', 'English']);
    });

    test('Issue 75: an empty list clears the preferred positions and '
        'languages', () async {
      if (skipUnless(
        enabled: capabilities.extendedProfile,
        module: 'extended profile',
      )) {
        return;
      }
      await sudo.users.setProfileOptions(options);
      await member.users.updateUser(
        memberName,
        preferredPositions: const ['Goalie'],
        preferredLanguages: const ['English'],
      );
      final cleared = await member.users.updateUser(
        memberName,
        preferredPositions: const [],
        preferredLanguages: const [],
      );
      expect(cleared.preferredPositions, isEmpty);
      expect(cleared.preferredLanguages, isEmpty);
      final me = await member.auth.getCurrentUser();
      expect(me.preferredPositions, isEmpty);
      expect(me.preferredLanguages, isEmpty);
    });

    test('Issue 75: a value listed twice is refused', () async {
      await expectLater(
        member.users.updateUser(
          memberName,
          preferredLanguages: const ['English', 'English'],
        ),
        refused(422, SdkErrorCode.validationError),
      );
    });

    test('Issue 75: a position or language that is not one of the club '
        'options is refused, naming the field and the value', () async {
      final before = await member.auth.getCurrentUser();
      for (final (field, value, update) in [
        (
          'preferredPositions',
          'Striker',
          () => member.users.updateUser(
            memberName,
            preferredPositions: const ['Striker'],
          ),
        ),
        (
          'preferredLanguages',
          'Klingon',
          () => member.users.updateUser(
            memberName,
            preferredLanguages: const ['Klingon'],
          ),
        ),
      ]) {
        await expectLater(
          update(),
          throwsA(
            isA<InvalidProfileOptionException>()
                .having((e) => e.statusCode, 'status', 422)
                .having((e) => e.field, 'field', field)
                .having((e) => e.value, 'value', value),
          ),
        );
      }
      final me = await member.auth.getCurrentUser();
      expect(me.preferredPositions, before.preferredPositions);
      expect(me.preferredLanguages, before.preferredLanguages);
    });
  });
}
