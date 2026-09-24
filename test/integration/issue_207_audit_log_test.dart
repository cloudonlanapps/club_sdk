import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 207: audit-log read surface (server #95 / `GET /v1/audit_log`).
///
/// Two access modes share the one endpoint:
/// - **Global feed** (no scope params): super-admin only.
/// - **Entity-scoped** (`username`, or `resourceType`+`resourceId`): any
///   admin or coach.
///
/// Rows come back newest-first with foreign keys resolved server-side, and
/// resolution ignores `deletedAt` so soft-deleted referents still carry their
/// stored names.
void main() {
  group('Issue 207: Audit log', () {
    late SecureClient sudoClient; // super-admin
    late SecureClient adminClient; // regular admin (not super)
    late SecureClient memberClient; // no roles

    const admin = 'test_audit_admin_207';
    const member = 'test_audit_member_207';
    const password = 'password123';

    late int venueId;
    late String venueName;
    late int groupId;
    late String groupName;

    setUpAll(() async {
      sudoClient = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: sudoClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      await sudoClient.auth.login(sudoUsername, sudoPassword);

      // A regular admin (not super-admin): can read entity-scoped history
      // but must be denied the global feed.
      await registerAndApprove(
        client: sudoClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: admin,
        email: '$admin@test.com',
        password: password,
        firstName: 'Audit Admin',
        phone: '0000000207',
        dateOfBirthUtc: DateTime.utc(1990),
        gender: Gender.male,
      );
      await sudoClient.users.assignRole(admin, 'admin');

      // A plain member: denied everywhere.
      await registerAndApprove(
        client: sudoClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: member,
        email: '$member@test.com',
        password: password,
        firstName: 'Audit Member',
        phone: '0000000307',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.female,
      );

      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login(admin, password);

      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await memberClient.auth.login(member, password);

      // Seed audit rows: the admin creates a venue and a group, so both the
      // global feed and the entity scopes have content with the admin as
      // actor.
      venueName = 'test_audit_venue_207';
      final venue = await adminClient.venues.createVenue(name: venueName);
      venueId = venue.id;

      groupName = 'test_audit_group_207';
      final group = await adminClient.groups.createGroup(name: groupName);
      groupId = group.id;
    });

    test('Issue 207: global feed requires super admin', () async {
      // A regular admin is denied the unscoped global feed...
      await expectLater(
        () => adminClient.auditLog.list(),
        throwsA(isA<ServerException>()),
      );
      // ...as is a plain member.
      await expectLater(
        () => memberClient.auditLog.list(),
        throwsA(isA<ServerException>()),
      );
    });

    test('Issue 207: super admin sees the global feed newest-first', () async {
      final page = await sudoClient.auditLog.list(limit: 100);

      expect(page.rows, isNotEmpty);
      expect(page.total, greaterThanOrEqualTo(page.rows.length));

      // Strictly newest-first by timestamp.
      for (var i = 0; i + 1 < page.rows.length; i++) {
        expect(
          page.rows[i].timestampUtc.isBefore(page.rows[i + 1].timestampUtc),
          isFalse,
          reason: 'rows must be ordered newest-first',
        );
      }

      // The seeded create_venue row is present with the actor name resolved
      // and a ready-to-render summary sentence.
      final createVenue = page.rows.firstWhere(
        (r) => r.action == 'create_venue' && r.resource?['id'] == venueId,
        orElse: () => throw StateError('create_venue row not found'),
      );
      expect(createVenue.actor?.username, admin);
      expect(createVenue.actor?.displayName, isNotEmpty);
      expect(createVenue.resource?['label'], venueName);
      expect(createVenue.summaryEn, isNotNull);
      expect(createVenue.summaryEn, contains(venueName));
    });

    test('Issue 207: admin can read venue-scoped history', () async {
      final page = await adminClient.auditLog.list(
        resourceType: 'venue',
        resourceId: venueId.toString(),
      );

      expect(page.rows, isNotEmpty);
      expect(
        page.rows.every((r) => r.resource?['id'] == venueId),
        isTrue,
        reason: 'every row in a venue scope must be about that venue',
      );
      expect(page.rows.any((r) => r.action == 'create_venue'), isTrue);
    });

    test('Issue 207: group scope returns the group rows', () async {
      final page = await adminClient.auditLog.list(
        resourceType: 'group',
        resourceId: groupId.toString(),
      );

      expect(page.rows.any((r) => r.action == 'create_group'), isTrue);
      final createGroup = page.rows.firstWhere(
        (r) => r.action == 'create_group',
      );
      expect(createGroup.resource?['label'], groupName);
    });

    test('Issue 207: username scope returns actor-or-target rows', () async {
      final page = await adminClient.auditLog.list(username: admin);

      expect(page.rows, isNotEmpty);
      // The admin is the actor on the venue/group creates.
      expect(
        page.rows.any((r) => r.actor?.username == admin),
        isTrue,
      );
    });

    test('Issue 207: resource scope needs both type and id', () async {
      // The client guards the paired-param contract before the round-trip.
      expect(
        () => adminClient.auditLog.list(resourceType: 'venue'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Issue 207: soft-deleted referent still resolves its name', () async {
      // Soft-delete the venue, then re-query its scope: the historical rows
      // must still carry the venue's stored name (resolution ignores
      // deletedAt).
      await adminClient.venues.deleteVenue(venueId);

      final page = await adminClient.auditLog.list(
        resourceType: 'venue',
        resourceId: venueId.toString(),
      );

      final createVenue = page.rows.firstWhere(
        (r) => r.action == 'create_venue',
        orElse: () => throw StateError('create_venue row vanished'),
      );
      expect(createVenue.resource?['label'], venueName);
    });
  });
}
