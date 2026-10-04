import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationStaffView', () {
    final view = EvaluationStaffView.fromMap(staffViewPayload());

    test('fromMap reads front matter, period and answers', () {
      expect(view.id, 21);
      expect(view.templateId, 5);
      expect(view.createdFor, 'member1');
      expect(view.createdBy, 'coach1');
      expect(view.owner, isNull);
      expect(view.eventId, 9);
      expect(
        view.periodStartUtc,
        DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
      );
      expect(
        view.periodEndUtc,
        DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
      );
      expect(view.status, EvaluationStatus.draft);
      expect(view.answers.single.itemId, 11);
      expect(view.publishedAtUtc, isNull);
      expect(view.deletedAtUtc, isNull);
    });

    test('the effective owner is the owner, else the creator', () {
      expect(view.effectiveOwner, 'coach1');
      expect(view.copyWith(owner: () => 'coach2').effectiveOwner, 'coach2');
    });

    test('isGeneral and isPublished', () {
      expect(view.isGeneral, isFalse);
      expect(view.copyWith(eventId: () => null).isGeneral, isTrue);
      expect(view.isPublished, isFalse);
      expect(
        view.copyWith(publishedAtUtc: () => DateTime.utc(2026)).isPublished,
        isTrue,
      );
    });

    test('answerFor finds an answer by item id', () {
      expect(view.answerFor(11)?.coachNote, 'Good edges');
      expect(view.answerFor(12), isNull);
    });

    test('round-trips through toMap and toJson', () {
      expect(view.toMap(), staffViewPayload());
      expect(EvaluationStaffView.fromMap(view.toMap()), view);
      expect(EvaluationStaffView.fromJson(view.toJson()), view);
    });

    test('copyWith clears the period, and equality', () {
      final cleared = view.copyWith(
        periodStartUtc: () => null,
        periodEndUtc: () => null,
      );
      expect(cleared.periodStartUtc, isNull);
      expect(cleared.periodEndUtc, isNull);
      expect(view.copyWith(), view);
      expect(view.hashCode, view.copyWith().hashCode);
      expect(view, isNot(view.copyWith(answers: const [])));
      expect(view, isNot(view.copyWith(status: EvaluationStatus.saved)));
    });
  });
}
