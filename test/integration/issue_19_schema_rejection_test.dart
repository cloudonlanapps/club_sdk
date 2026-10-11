import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Issue 19: a request the server rejects at its schema (422) reaches the
/// caller with the fields it refuses, under
/// [ServerException.refusedFieldsKey].
///
/// The SDK's own calls build valid requests, so these post a user raw
/// through the [RemoteStore] with fields the schema refuses.
void main() {
  group('Issue 19: a schema rejection names its fields', () {
    late RemoteStore store;
    late SecureClient admin;

    const username = 'test_i19_user';

    Future<ServerException> refusal(Map<String, dynamic> change) async {
      final body = <String, dynamic>{
        'username': username,
        'email': '$username@test.com',
        'passwordHash': 'password123',
        'phone': '0000000019',
        'dateOfBirthUtc': DateTime.utc(1995).millisecondsSinceEpoch,
        'gender': Gender.male.serverValue,
        'firstName': username,
        ...change,
      };
      try {
        await store.post('/users', body: body);
      } on ServerException catch (e) {
        return e;
      }
      fail('the server accepted $change');
    }

    List<List<dynamic>> refusedPaths(ServerException e) => [
      for (final field
          in e.details![ServerException.refusedFieldsKey] as List<dynamic>)
        (field as Map<String, dynamic>)['loc'] as List<dynamic>,
    ];

    setUpAll(() async {
      store = RemoteStore(baseUrl: baseUrl);
      admin = await createRemoteSecureClient(baseUrl: baseUrl, store: store);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('Issue 19: one refused field is named with its reason', () async {
      final e = await refusal({'status': 'test_i19_no_such_status'});

      expect(e.statusCode, 422);
      expect(e.code, SdkErrorCode.validationError);
      expect(refusedPaths(e), [
        ['body', 'status'],
      ]);
      final field =
          (e.details![ServerException.refusedFieldsKey] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(field['msg'], isA<String>().having((m) => m, 'msg', isNotEmpty));
      expect(e.message, contains(field['msg'] as String));
      expect(field.keys, ['loc', 'msg', 'type']);
    });

    test('Issue 19: two refused fields are both named', () async {
      final e = await refusal({
        'status': 'test_i19_no_such_status',
        'firstName': 'x' * 101,
      });

      expect(e.code, SdkErrorCode.validationError);
      expect(
        refusedPaths(e),
        unorderedEquals([
          ['body', 'status'],
          ['body', 'firstName'],
        ]),
      );
    });

    test('Issue 19: a refused request creates no user', () async {
      await refusal({'status': 'test_i19_no_such_status'});

      await expectLater(
        admin.users.getUserPrivate(username),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.userNotFound,
          ),
        ),
      );
    });
  });
}
