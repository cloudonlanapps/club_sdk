import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 31: the SDK names the notification types the server added since the
/// server's 0.5 release; unknown strings still pass through `AppNotification`.
void main() {
  group('Issue 31: NotificationType', () {
    test('Issue 31: names every type added since 0.5', () {
      expect(NotificationType.addedSinceRelease05, {
        'event.terminated',
        'event.extended',
        'event.conflict_detected',
        'credit.released',
        'evaluation.published',
        'evaluation.withdrawn',
        'evaluation.transferred',
        'inquiry.received',
      });
      expect(
        NotificationType.all,
        containsAll(NotificationType.addedSinceRelease05),
      );
    });

    test('Issue 31: every constant uses the domain.event wire shape', () {
      for (final type in NotificationType.all) {
        expect(type, matches(RegExp(r'^[a-z_]+\.[a-z_]+$')), reason: type);
      }
    });

    test('Issue 31: isKnown distinguishes known from unknown', () {
      expect(NotificationType.isKnown('event.terminated'), isTrue);
      expect(NotificationType.isKnown('group.member_added'), isTrue);
      expect(NotificationType.isKnown('future.type'), isFalse);
    });

    test('Issue 30: enrollment.trial_ended is a known type', () {
      expect(NotificationType.enrollmentTrialEnded, 'enrollment.trial_ended');
      expect(NotificationType.all, contains('enrollment.trial_ended'));
      expect(NotificationType.isKnown('enrollment.trial_ended'), isTrue);
    });

    test('Issue 7: group.member_ineligible is a known type', () {
      expect(NotificationType.groupMemberIneligible, 'group.member_ineligible');
      expect(NotificationType.all, contains('group.member_ineligible'));
      expect(NotificationType.isKnown('group.member_ineligible'), isTrue);
    });

    test('Issue 7: a group.member_ineligible notification carries the group '
        'and the member', () {
      final n = AppNotification.fromMap(const <String, dynamic>{
        'id': 3,
        'username': 'admin',
        'type': 'group.member_ineligible',
        'channel': 'in_app',
        'payload': <String, dynamic>{
          'v': 1,
          'type': 'group.member_ineligible',
          'data': <String, dynamic>{
            'groupId': 5,
            'groupName': 'test_U12',
            'membername': 'amy',
          },
        },
        'isRead': false,
        'createdAtUtc': 1791244800000,
      });
      expect(n.type, NotificationType.groupMemberIneligible);
      final data = n.payload['data'] as Map<String, dynamic>;
      expect(data['groupId'], 5);
      expect(data['groupName'], 'test_U12');
      expect(data['membername'], 'amy');
    });

    test('Issue 30: the trial-ended withdrawal reason is named', () {
      expect(Enrollment.trialCreditExhaustedReason, 'trialCreditExhausted');
    });

    test(
      'Issue 31: an unknown type still round-trips through AppNotification',
      () {
        final wire = <String, dynamic>{
          'id': 1,
          'username': 'u',
          'type': 'future.type',
          'channel': 'in_app',
          'payload': <String, dynamic>{},
          'isRead': false,
          'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        };
        final n = AppNotification.fromMap(wire);
        expect(n.type, 'future.type');
        expect(AppNotification.fromMap(n.toMap()), n);
      },
    );
  });
}
