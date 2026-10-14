import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Issue 22: an inquiry's message is optional (club_server#41).
///
/// Whether a form needs a message is the caller's to decide: an inquiry of
/// either kind may be sent without one and is listed with `message` null.
/// An empty message is still refused.
void main() {
  group('Issue 22: an inquiry without a message', () {
    late SecureClient admin;
    late SecureClient anon;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      anon = await createRemoteSecureClient(baseUrl: baseUrl);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    /// A form token old enough that the server keeps the submission.
    Future<String> readyToken() async {
      final token = await anon.public.getInquiryFormToken();
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      return token;
    }

    for (final kind in InquiryKind.values) {
      test(
        'Issue 22: a ${kind.wireName} inquiry without a message is stored '
        'and listed with no message',
        () async {
          final name = 'test_i22_${kind.wireName}';
          await anon.public.submitInquiry(
            kind: kind,
            name: name,
            email: 'test_i22_${kind.wireName}@test.com',
            token: await readyToken(),
          );

          final inbox = await admin.inquiries.listInquiries(
            kind: kind,
            limit: 100,
          );
          final ours = inbox.items.where((i) => i.name == name).toList();
          expect(ours, hasLength(1));
          expect(ours.single.kind, kind);
          expect(ours.single.message, isNull);
        },
      );
    }

    test('Issue 22: an empty message is refused', () async {
      await expectLater(
        anon.public.submitInquiry(
          kind: InquiryKind.contact,
          name: 'test_i22_empty',
          email: 'test_i22_empty@test.com',
          message: '',
          token: await readyToken(),
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            422,
          ),
        ),
      );

      final inbox = await admin.inquiries.listInquiries(limit: 100);
      expect(
        inbox.items.map((i) => i.name),
        isNot(contains('test_i22_empty')),
      );
    });
  });
}
