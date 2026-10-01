import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationMemberView', () {
    final view = EvaluationMemberView.fromMap(memberViewPayload());

    test('fromMap reads the template and public answers', () {
      expect(view.id, 21);
      expect(view.createdFor, 'member1');
      expect(view.createdBy, 'coach1');
      expect(view.owner, 'coach2');
      expect(view.effectiveOwner, 'coach2');
      expect(view.eventId, isNull);
      expect(view.status, EvaluationStatus.published);
      expect(
        view.publishedAtUtc,
        DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );
      expect(view.template.name, 'Term review');
      expect(view.answers.single.coachNote, 'Good edges');
    });

    test('round-trips through toMap and toJson', () {
      expect(view.toMap(), memberViewPayload());
      expect(EvaluationMemberView.fromMap(view.toMap()), view);
      expect(EvaluationMemberView.fromJson(view.toJson()), view);
    });

    test('copyWith and equality', () {
      expect(view.copyWith(owner: () => null).effectiveOwner, 'coach1');
      expect(view.copyWith(), view);
      expect(view.hashCode, view.copyWith().hashCode);
      expect(view, isNot(view.copyWith(answers: const [])));
    });
  });
}
