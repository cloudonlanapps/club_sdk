import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationTemplateItemHit', () {
    final payload = {
      'templateId': 5,
      'templateName': 'Term review',
      'item': ratingItemPayload(),
    };
    final hit = EvaluationTemplateItemHit.fromMap(payload);

    test('fromMap reads the template and its item', () {
      expect(hit.templateId, 5);
      expect(hit.templateName, 'Term review');
      expect(hit.item, isA<EvaluationRatingItem>());
    });

    test('round-trips, copyWith and equality', () {
      expect(hit.toMap(), payload);
      expect(EvaluationTemplateItemHit.fromMap(hit.toMap()), hit);
      expect(EvaluationTemplateItemHit.fromJson(hit.toJson()), hit);
      expect(hit.copyWith(templateId: 6).templateId, 6);
      expect(hit.copyWith(), hit);
      expect(hit.hashCode, hit.copyWith().hashCode);
      expect(
        hit,
        isNot(
          hit.copyWith(item: EvaluationTemplateItem.fromMap(qaItemPayload())),
        ),
      );
    });
  });
}
