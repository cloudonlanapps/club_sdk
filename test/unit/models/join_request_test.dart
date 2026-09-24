import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('JoinRequestStatus', () {
    test('fromWire parses every known value', () {
      expect(JoinRequestStatus.fromWire('pending'), JoinRequestStatus.pending);
      expect(
        JoinRequestStatus.fromWire('approved'),
        JoinRequestStatus.approved,
      );
      expect(
        JoinRequestStatus.fromWire('rejected'),
        JoinRequestStatus.rejected,
      );
      expect(
        JoinRequestStatus.fromWire('cancelled'),
        JoinRequestStatus.cancelled,
      );
    });

    test('fromWire throws for unknown values', () {
      expect(
        () => JoinRequestStatus.fromWire('exploded'),
        throwsArgumentError,
      );
    });
  });

  group('JoinRequest', () {
    const pending = JoinRequest(
      id: 42,
      groupId: 7,
      groupName: 'U15 Boys',
      username: 'alice',
      status: JoinRequestStatus.pending,
      requestedAt: 1700000000000,
    );

    const approved = JoinRequest(
      id: 42,
      groupId: 7,
      groupName: 'U15 Boys',
      username: 'alice',
      status: JoinRequestStatus.approved,
      requestedAt: 1700000000000,
      decidedAt: 1700000060000,
      decidedBy: 'admin',
      reason: 'looks good',
    );

    test('round-trips through toMap / fromMap', () {
      expect(JoinRequest.fromMap(pending.toMap()), pending);
      expect(JoinRequest.fromMap(approved.toMap()), approved);
    });

    test('round-trips through toJson / fromJson', () {
      expect(JoinRequest.fromJson(approved.toJson()), approved);
    });

    test('equality is value-based', () {
      const same = JoinRequest(
        id: 42,
        groupId: 7,
        groupName: 'U15 Boys',
        username: 'alice',
        status: JoinRequestStatus.pending,
        requestedAt: 1700000000000,
      );
      expect(pending, same);
      expect(pending.hashCode, same.hashCode);
    });

    test('copyWith replaces non-null fields', () {
      final flipped = pending.copyWith(
        status: JoinRequestStatus.approved,
        decidedAt: () => 1700000060000,
        decidedBy: () => 'admin',
        reason: () => 'looks good',
      );
      expect(flipped, approved);
    });

    test('copyWith clears nullable fields via ValueGetter', () {
      final cleared = approved.copyWith(
        decidedAt: () => null,
        decidedBy: () => null,
        reason: () => null,
      );
      expect(cleared.decidedAt, isNull);
      expect(cleared.decidedBy, isNull);
      expect(cleared.reason, isNull);
    });

    test('copyWith without explicit ValueGetter preserves nullables', () {
      final preserved = approved.copyWith(status: JoinRequestStatus.rejected);
      expect(preserved.status, JoinRequestStatus.rejected);
      expect(preserved.decidedAt, approved.decidedAt);
      expect(preserved.decidedBy, approved.decidedBy);
      expect(preserved.reason, approved.reason);
    });

    test('serialises status by name', () {
      expect(approved.toMap()['status'], 'approved');
    });
  });
}
