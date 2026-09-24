import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Broadcast Model Unit Tests (AudienceSelector, Broadcast,
/// BroadcastRecipient).
///
/// Verifies the SDK's wire contract matches the server's BroadcastResponse /
/// BroadcastDetail / BroadcastRecipient schemas (see club_server's
/// schemas/broadcast.py).
void main() {
  group('AudienceKind', () {
    test('wire names match server contract', () {
      expect(AudienceKind.allUsers.wireName, 'all_users');
      expect(AudienceKind.role.wireName, 'role');
      expect(AudienceKind.group.wireName, 'group');
      expect(AudienceKind.eventMembers.wireName, 'event_members');
      expect(AudienceKind.eventStaff.wireName, 'event_staff');
      expect(AudienceKind.users.wireName, 'users');
    });

    test('fromWire parses known values', () {
      expect(AudienceKind.fromWire('all_users'), AudienceKind.allUsers);
      expect(AudienceKind.fromWire('event_staff'), AudienceKind.eventStaff);
    });

    test('fromWire throws on unknown', () {
      expect(() => AudienceKind.fromWire('robots'), throwsArgumentError);
    });
  });

  group('AudienceSelector', () {
    test('allUsers serializes to {kind: all_users}', () {
      const sel = AudienceSelector.allUsers();
      expect(sel.toMap(), {'kind': 'all_users'});
      expect(sel.kind, AudienceKind.allUsers);
      expect(sel.role, isNull);
    });

    test('role serializes with role field', () {
      const sel = AudienceSelector.role('admin');
      expect(sel.toMap(), {'kind': 'role', 'role': 'admin'});
    });

    test('group serializes with groupId field', () {
      const sel = AudienceSelector.group(42);
      expect(sel.toMap(), {'kind': 'group', 'groupId': 42});
    });

    test('eventMembers serializes with eventId field', () {
      const sel = AudienceSelector.eventMembers(7);
      expect(sel.toMap(), {'kind': 'event_members', 'eventId': 7});
    });

    test('eventStaff serializes with eventId field', () {
      const sel = AudienceSelector.eventStaff(7);
      expect(sel.toMap(), {'kind': 'event_staff', 'eventId': 7});
    });

    test('users serializes with usernames list', () {
      final sel = AudienceSelector.users(const ['alice', 'bob']);
      expect(sel.toMap(), {
        'kind': 'users',
        'usernames': ['alice', 'bob'],
      });
    });

    test('fromMap restores allUsers', () {
      final sel = AudienceSelector.fromMap(const {'kind': 'all_users'});
      expect(sel, const AudienceSelector.allUsers());
    });

    test('fromMap restores role', () {
      final sel = AudienceSelector.fromMap(
        const {'kind': 'role', 'role': 'coach'},
      );
      expect(sel, const AudienceSelector.role('coach'));
    });

    test('fromMap restores users with empty list when missing', () {
      final sel = AudienceSelector.fromMap(const {'kind': 'users'});
      expect(sel.kind, AudienceKind.users);
      expect(sel.usernames, isEmpty);
    });

    test('toMap/fromMap roundtrip preserves all kinds', () {
      final cases = <AudienceSelector>[
        const AudienceSelector.allUsers(),
        const AudienceSelector.role('admin'),
        const AudienceSelector.group(12),
        const AudienceSelector.eventMembers(3),
        const AudienceSelector.eventStaff(4),
        AudienceSelector.users(const ['a', 'b']),
      ];
      for (final original in cases) {
        final restored = AudienceSelector.fromMap(original.toMap());
        expect(restored, original);
        expect(restored.hashCode, original.hashCode);
      }
    });

    test('equality differentiates between kinds with overlapping fields', () {
      expect(
        const AudienceSelector.eventMembers(1),
        isNot(const AudienceSelector.eventStaff(1)),
      );
    });

    test('users equality compares lists by value', () {
      expect(
        AudienceSelector.users(const ['a', 'b']),
        AudienceSelector.users(const ['a', 'b']),
      );
      expect(
        AudienceSelector.users(const ['a', 'b']),
        isNot(AudienceSelector.users(const ['b', 'a'])),
      );
    });
  });

  group('BroadcastStatus', () {
    test('wire names match server contract', () {
      expect(BroadcastStatus.sent.wireName, 'sent');
      expect(BroadcastStatus.revoked.wireName, 'revoked');
    });

    test('fromWire defaults to sent for unknown values', () {
      expect(BroadcastStatus.fromWire('garbage'), BroadcastStatus.sent);
    });
  });

  group('Broadcast', () {
    final sentAt = DateTime.utc(2026, 3, 1, 9);
    final expiresAt = DateTime.utc(2026, 3, 8, 9);
    final broadcast = Broadcast(
      id: 1,
      senderUsername: 'admin',
      audienceSelector: const AudienceSelector.role('coach'),
      payload: const {
        'v': 1,
        'type': 'broadcast.message',
        'data': <String, dynamic>{'title': 'Heads up'},
      },
      sentAtUtc: sentAt,
      expiresAtUtc: expiresAt,
      status: BroadcastStatus.sent,
      recipientCount: 5,
      readCount: 2,
      unreadCount: 3,
    );

    test('value equality compares all fields', () {
      final same = Broadcast(
        id: 1,
        senderUsername: 'admin',
        audienceSelector: const AudienceSelector.role('coach'),
        payload: const {
          'v': 1,
          'type': 'broadcast.message',
          'data': <String, dynamic>{'title': 'Heads up'},
        },
        sentAtUtc: sentAt,
        expiresAtUtc: expiresAt,
        status: BroadcastStatus.sent,
        recipientCount: 5,
        readCount: 2,
        unreadCount: 3,
      );
      expect(broadcast, same);
      expect(broadcast.hashCode, same.hashCode);
    });

    test('payload deep equality detects nested diff', () {
      final diff = broadcast.copyWith(
        payload: const {
          'v': 1,
          'type': 'broadcast.message',
          'data': <String, dynamic>{'title': 'Different'},
        },
      );
      expect(broadcast, isNot(diff));
    });

    test('copyWith clears nullable expiresAtUtc via ValueGetter', () {
      final cleared = broadcast.copyWith(expiresAtUtc: () => null);
      expect(cleared.expiresAtUtc, isNull);
      expect(cleared.id, broadcast.id);
    });

    test('copyWith clears read/unread counters via ValueGetter', () {
      final listRow = broadcast.copyWith(
        readCount: () => null,
        unreadCount: () => null,
      );
      expect(listRow.readCount, isNull);
      expect(listRow.unreadCount, isNull);
      // recipientCount stays — it's required on every response shape.
      expect(listRow.recipientCount, 5);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = Broadcast.fromMap(broadcast.toMap());
      expect(restored, broadcast);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final restored = Broadcast.fromJson(broadcast.toJson());
      expect(restored, broadcast);
    });

    test('fromMap parses list-row shape (no read/unread counters)', () {
      final map = {
        'id': 9,
        'senderUsername': 'admin',
        'audienceSelector': const {'kind': 'all_users'},
        'payload': const {
          'v': 1,
          'type': 'broadcast.message',
          'data': <String, dynamic>{},
        },
        'sentAtUtc': sentAt.millisecondsSinceEpoch,
        'expiresAtUtc': null,
        'status': 'sent',
        'recipientCount': 12,
      };
      final b = Broadcast.fromMap(map);
      expect(b.id, 9);
      expect(b.audienceSelector, const AudienceSelector.allUsers());
      expect(b.recipientCount, 12);
      expect(b.expiresAtUtc, isNull);
      expect(b.readCount, isNull);
      expect(b.unreadCount, isNull);
    });

    test('fromMap parses status revoked', () {
      final map = broadcast.toMap()..['status'] = 'revoked';
      final b = Broadcast.fromMap(map);
      expect(b.status, BroadcastStatus.revoked);
    });
  });

  group('BroadcastRecipient', () {
    final createdAt = DateTime.utc(2026, 3, 1, 9);
    final recipient = BroadcastRecipient(
      username: 'alice',
      isRead: true,
      createdAtUtc: createdAt,
    );

    test('value equality compares all fields', () {
      final same = BroadcastRecipient(
        username: 'alice',
        isRead: true,
        createdAtUtc: createdAt,
      );
      expect(recipient, same);
      expect(recipient.hashCode, same.hashCode);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = BroadcastRecipient.fromMap(recipient.toMap());
      expect(restored, recipient);
    });

    test('fromMap defaults isRead to false when missing', () {
      final map = {
        'username': 'bob',
        'createdAtUtc': createdAt.millisecondsSinceEpoch,
      };
      final r = BroadcastRecipient.fromMap(map);
      expect(r.isRead, isFalse);
    });

    test('copyWith creates new instance with changed field', () {
      final updated = recipient.copyWith(isRead: false);
      expect(updated.username, recipient.username);
      expect(updated.isRead, isFalse);
    });
  });
}
