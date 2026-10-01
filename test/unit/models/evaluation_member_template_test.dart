import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationMemberTemplate', () {
    final payload = memberViewPayload()['template'] as Map<String, dynamic>;
    final template = EvaluationMemberTemplate.fromMap(payload);

    test('fromMap reads the public layout and items', () {
      expect(template.id, 5);
      expect(template.name, 'Term review');
      expect(template.layout, const [
        EvaluationLayoutSection<int>('Skills', [11]),
      ]);
      expect(template.items.single, isA<EvaluationRatingItem>());
    });

    test('round-trips, copyWith and equality', () {
      expect(template.toMap(), payload);
      expect(EvaluationMemberTemplate.fromMap(template.toMap()), template);
      expect(EvaluationMemberTemplate.fromJson(template.toJson()), template);
      expect(template.copyWith(name: 'x').name, 'x');
      expect(template.copyWith(), template);
      expect(template.hashCode, template.copyWith().hashCode);
      expect(template, isNot(template.copyWith(items: const [])));
    });
  });
}
