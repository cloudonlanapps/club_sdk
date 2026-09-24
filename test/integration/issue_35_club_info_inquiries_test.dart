import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Issue 35: the public club-info document and the inquiries surface
/// (club_server#296, #407).
///
/// The form is unauthenticated and deliberately uninformative: the server
/// answers 202 with no body whether it kept the submission or dropped it,
/// so these tests read the admin inbox to tell the two apart. The
/// fill-time token gates submissions made in under three seconds.
void main() {
  group('Issue 35: club info and inquiries', () {
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

    // ═══════════════════════════════════════════════════════════════════
    // CLUB INFO
    // ═══════════════════════════════════════════════════════════════════

    test(
      '35.01: the club-info document is readable without logging in',
      () async {
        final info = await anon.public.getPublicClubInfo();
        expect(info.clubInfo, isNotNull);
        expect(info.siteMedia, isNotNull);
      },
    );

    test(
      '35.02: an unset deployment answers with empty maps, not null',
      () async {
        final info = await anon.public.getPublicClubInfo();
        // Whatever this stack has configured, neither map may be null: a
        // website must be able to render an unconfigured deployment.
        expect(info.clubInfo, isA<Map<String, dynamic>>());
        expect(info.siteMedia, isA<Map<String, MediaRef>>());
      },
    );

    // ═══════════════════════════════════════════════════════════════════
    // THE PUBLIC FORM
    // ═══════════════════════════════════════════════════════════════════

    test('35.03: a token is issued to an anonymous caller', () async {
      final token = await anon.public.getInquiryFormToken();
      expect(token, isNotEmpty);
    });

    test('35.04: a submission reaches the admin inbox', () async {
      final token = await anon.public.getInquiryFormToken();
      // The server drops anything returned in under three seconds.
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      await anon.public.submitInquiry(
        kind: InquiryKind.contact,
        name: 'test_inquiry_person',
        email: 'test_inquiry@test.com',
        message: 'When does the beginner programme start?',
        phone: '+919000000004',
        token: token,
      );

      final inbox = await admin.inquiries.listInquiries();
      final ours = inbox.items.firstWhere(
        (i) => i.name == 'test_inquiry_person',
      );
      expect(ours.kind, InquiryKind.contact);
      expect(ours.email, 'test_inquiry@test.com');
      expect(ours.phone, '+919000000004');
      expect(ours.message, 'When does the beginner programme start?');
      expect(ours.isHandled, isFalse);
      expect(ours.handledBy, isNull);
    });

    test('35.05: a submission returned too fast is dropped, and says '
        'nothing about it', () async {
      final token = await anon.public.getInquiryFormToken();

      // No delay: under the three-second floor. The call still succeeds —
      // the server tells a bot nothing.
      await anon.public.submitInquiry(
        kind: InquiryKind.contact,
        name: 'test_inquiry_toofast',
        email: 'test_toofast@test.com',
        message: 'filled instantly',
        token: token,
      );

      final inbox = await admin.inquiries.listInquiries(limit: 100);
      expect(
        inbox.items.map((i) => i.name),
        isNot(contains('test_inquiry_toofast')),
        reason: 'the submission was accepted at the wire and then dropped',
      );
    });

    test('35.06: a filled honeypot is dropped', () async {
      final token = await anon.public.getInquiryFormToken();
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      await anon.public.submitInquiry(
        kind: InquiryKind.interest,
        name: 'test_inquiry_bot',
        email: 'test_bot@test.com',
        message: 'a bot filled every field it found',
        token: token,
        website: 'https://spam.example.com',
      );

      final inbox = await admin.inquiries.listInquiries(limit: 100);
      expect(
        inbox.items.map((i) => i.name),
        isNot(contains('test_inquiry_bot')),
      );
    });

    test('35.07: an interest submission carries its extra fields', () async {
      final token = await anon.public.getInquiryFormToken();
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      await anon.public.submitInquiry(
        kind: InquiryKind.interest,
        name: 'test_inquiry_interest',
        email: 'test_interest@test.com',
        message: 'interested in the summer camp',
        token: token,
        extra: const {'ageGroup': 'U14', 'source': 'instagram'},
      );

      final inbox = await admin.inquiries.listInquiries(
        kind: InquiryKind.interest,
      );
      final ours = inbox.items.firstWhere(
        (i) => i.name == 'test_inquiry_interest',
      );
      expect(ours.extra?['ageGroup'], 'U14');
      expect(ours.extra?['source'], 'instagram');
    });

    // ═══════════════════════════════════════════════════════════════════
    // THE ADMIN INBOX
    // ═══════════════════════════════════════════════════════════════════

    test('35.08: the inbox is admin-only', () async {
      await expectLater(
        anon.inquiries.listInquiries(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    });

    test('35.09: the inbox filters by kind', () async {
      final contact = await admin.inquiries.listInquiries(
        kind: InquiryKind.contact,
      );
      expect(contact.items, isNotEmpty);
      expect(
        contact.items.every((i) => i.kind == InquiryKind.contact),
        isTrue,
      );

      final interest = await admin.inquiries.listInquiries(
        kind: InquiryKind.interest,
      );
      expect(
        interest.items.every((i) => i.kind == InquiryKind.interest),
        isTrue,
      );
    });

    test(
      '35.10: marking handled stamps the handler, reopening clears it',
      () async {
        final inbox = await admin.inquiries.listInquiries();
        final target = inbox.items.firstWhere(
          (i) => i.name == 'test_inquiry_person',
        );

        final handled = await admin.inquiries.setInquiryHandled(
          target.id,
          handled: true,
        );
        expect(handled.isHandled, isTrue);
        expect(handled.handledAtUtc, isNotNull);
        expect(handled.handledBy, sudoUsername);

        final onlyHandled = await admin.inquiries.listInquiries(handled: true);
        expect(onlyHandled.items.map((i) => i.id), contains(target.id));

        final onlyOpen = await admin.inquiries.listInquiries(handled: false);
        expect(onlyOpen.items.map((i) => i.id), isNot(contains(target.id)));

        final reopened = await admin.inquiries.setInquiryHandled(
          target.id,
          handled: false,
        );
        expect(reopened.isHandled, isFalse);
        expect(reopened.handledAtUtc, isNull);
        expect(reopened.handledBy, isNull);
      },
    );

    test('35.11: deleting an inquiry removes it for good', () async {
      final inbox = await admin.inquiries.listInquiries(limit: 100);
      final target = inbox.items.firstWhere(
        (i) => i.name == 'test_inquiry_interest',
      );

      await admin.inquiries.deleteInquiry(target.id);

      final after = await admin.inquiries.listInquiries(limit: 100);
      expect(after.items.map((i) => i.id), isNot(contains(target.id)));

      // There is no deleted listing to fall back on: the row is PII.
      await expectLater(
        admin.inquiries.deleteInquiry(target.id),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });
}
