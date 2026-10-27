import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/user_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 66: the extended profile fields on `updateUser`, and the club's
/// profile options, read at `/system/preferences/profile_options`
/// (club_server#92) and written at `/admin/preferences/profile_options`
/// (club_server#98, #74).
const Map<String, Object> userResponse = {
  'username': 'u1',
  'publicId': 'p1',
  'status': 'active',
  'isSuperAdmin': false,
  'roles': <String>[],
  'createdAtUtc': 1767225600000,
};

const Map<String, Object> optionsResponse = {
  'positions': [
    {
      'value': 'Forward',
      'label': {'en': 'Forward', 'mr': 'फॉरवर्ड'},
    },
  ],
  'languages': ['English', 'Marathi'],
};

({RemoteUserSource source, List<http.Request> requests}) harness({
  Object body = userResponse,
  int status = 200,
}) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteUserSource(store), requests: requests);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  group('RemoteUserSource.updateUser extended fields', () {
    test('Issue 66: sends every extended field under its server key', () async {
      final h = harness();
      await h.source.updateUser(
        'u1',
        clubDistrict: () => 'Pune District',
        preferredPositions: const ['Forward', 'Goalie'],
        pastExperience: () => 'Two seasons.',
        nationality: () => 'Indian',
        preferredLanguages: const ['Marathi', 'English'],
        guardian: () => const Guardian(name: 'Asha', relation: 'Mother'),
        membershipDateUtc: () => DateTime.utc(2024, 4),
      );
      final request = h.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/v1/users/by_id/u1');
      expect(bodyOf(request), {
        'clubDistrict': 'Pune District',
        'preferredPositions': ['Forward', 'Goalie'],
        'pastExperience': 'Two seasons.',
        'nationality': 'Indian',
        'preferredLanguages': ['Marathi', 'English'],
        'guardian': {'name': 'Asha', 'relation': 'Mother', 'phone': null},
        'membershipDateUtc': DateTime.utc(2024, 4).millisecondsSinceEpoch,
      });
    });

    test(
      'Issue 66: a getter returning null sends null, which clears',
      () async {
        final h = harness();
        await h.source.updateUser(
          'u1',
          clubDistrict: () => null,
          guardian: () => null,
          membershipDateUtc: () => null,
        );
        expect(bodyOf(h.requests.single), {
          'clubDistrict': null,
          'guardian': null,
          'membershipDateUtc': null,
        });
      },
    );

    test('Issue 75: an empty list clears the preferred positions and '
        'languages', () async {
      final h = harness();
      await h.source.updateUser(
        'u1',
        preferredPositions: const [],
        preferredLanguages: const [],
      );
      expect(bodyOf(h.requests.single), {
        'preferredPositions': <String>[],
        'preferredLanguages': <String>[],
      });
    });

    test('Issue 66: an omitted extended field is not sent', () async {
      final h = harness();
      await h.source.updateUser('u1', nationality: () => 'Indian');
      expect(bodyOf(h.requests.single), {'nationality': 'Indian'});
    });

    test('Issue 66: reads the extended fields from the response', () async {
      final h = harness(
        body: {
          ...userResponse,
          'preferredLanguages': ['Marathi', 'English'],
          'guardian': {'name': 'Asha'},
          'membershipDateUtc': DateTime.utc(2024, 4).millisecondsSinceEpoch,
        },
      );
      final user = await h.source.updateUser(
        'u1',
        preferredLanguages: const ['Marathi', 'English'],
      );
      expect(user.preferredLanguages, ['Marathi', 'English']);
      expect(user.preferredPositions, isEmpty);
      expect(user.guardian, const Guardian(name: 'Asha'));
      expect(user.membershipDateUtc, DateTime.utc(2024, 4));
    });
  });

  group('RemoteUserSource profile options', () {
    test('Issue 66: getProfileOptions reads the preference', () async {
      final h = harness(body: optionsResponse);
      final options = await h.source.getProfileOptions();
      final request = h.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/system/preferences/profile_options');
      expect(options, ProfileOptions.fromMap(optionsResponse));
    });

    test("Issue 74: setProfileOptions patches the super admin's preference "
        'with the whole document as its value and reads the stored one '
        'back', () async {
      final h = harness(
        body: {
          'key': 'profile_options',
          'value': optionsResponse,
          'updatedAtUtc': 1767225600000,
          'updatedBy': 'sudo',
        },
      );
      final options = ProfileOptions.fromMap(optionsResponse);
      final written = await h.source.setProfileOptions(options);
      final request = h.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/v1/admin/preferences/profile_options');
      expect(bodyOf(request), {'value': optionsResponse});
      expect(written, options);
    });

    test('Issue 74: setProfileOptions surfaces an invalid document as '
        'INVALID_PREFERENCE_VALUE', () async {
      final h = harness(
        status: 422,
        body: {
          'detail': {
            'code': 'INVALID_PREFERENCE_VALUE',
            'message': 'profile_options: a language is listed twice',
          },
        },
      );
      await expectLater(
        h.source.setProfileOptions(
          const ProfileOptions(languages: ['English', 'English']),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 422)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.invalidPreferenceValue,
              ),
        ),
      );
    });

    test('Issue 66: setProfileOptions surfaces a disabled extended profile '
        'as ModuleDisabledException', () async {
      final h = harness(
        status: 503,
        body: {
          'detail': {
            'code': 'EXTENDED_PROFILE_DISABLED',
            'message': 'The extended profile is not enabled',
          },
        },
      );
      await expectLater(
        h.source.setProfileOptions(const ProfileOptions()),
        throwsA(
          isA<ModuleDisabledException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.extendedProfileDisabled,
          ),
        ),
      );
    });
  });
}
