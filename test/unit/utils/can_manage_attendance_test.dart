import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 29: club_server#247 lets a coach assigned to an event mark and
/// clear attendance and decide leave on it, alongside the organizer and
/// admins. The client-side gate must admit the same three tiers.
UserPrivate user(String username, {bool isAdmin = false}) => UserPrivate(
  username: username,
  displayName: username,
  status: UserStatus.active,
  isSuperAdmin: false,
  roles: UserRoles(isAdmin: isAdmin, isCoach: !isAdmin),
  createdAtUtc: DateTime.utc(2024),
);

Event event({String? organizerName, List<String>? coachNames}) => Event(
  id: 1,
  title: 't',
  description: '',
  type: EventType.programme,
  visibility: Visibility.public,
  venueId: 1,
  organizerName: organizerName,
  coachNames: coachNames,
  startTimeUtc: DateTime.utc(2030),
  endTimeUtc: DateTime.utc(2030, 1, 1, 1),
  createdAtUtc: DateTime.utc(2024),
  updatedAtUtc: DateTime.utc(2024),
);

void main() {
  group('Issue 29: canManageAttendance', () {
    final e = event(organizerName: 'org', coachNames: const ['c1', 'c2']);

    test('Issue 29: an admin may manage attendance', () {
      expect(canManageAttendance(e, user('someone', isAdmin: true)), isTrue);
    });

    test('Issue 29: the organizer may manage attendance', () {
      expect(canManageAttendance(e, user('org')), isTrue);
    });

    test('Issue 29: an assigned coach may manage attendance', () {
      expect(canManageAttendance(e, user('c1')), isTrue);
      expect(canManageAttendance(e, user('c2')), isTrue);
    });

    test('Issue 29: a coach not on the event may not', () {
      expect(canManageAttendance(e, user('c3')), isFalse);
    });

    test('Issue 29: an event with no coaches admits only admin/organizer', () {
      final bare = event(organizerName: 'org');
      expect(canManageAttendance(bare, user('c1')), isFalse);
      expect(canManageAttendance(bare, user('org')), isTrue);
    });
  });
}
