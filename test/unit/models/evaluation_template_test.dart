import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationTemplate', () {
    final template = EvaluationTemplate.fromMap(templatePayload());

    test('fromMap reads front matter, layout and items', () {
      expect(template.id, 5);
      expect(template.name, 'Term review');
      expect(template.createdBy, 'admin1');
      expect(template.layout, const [
        EvaluationLayoutItem<int>(18),
        EvaluationLayoutSection<int>('Skills', [11, 13]),
      ]);
      expect(template.items.map((i) => i.id), [18, 11, 13]);
      expect(template.items.first, isA<EvaluationInfoItem>());
      expect(template.createdAtUtc, DateTime.utc(1970, 1, 1, 0, 0, 1));
      expect(template.deletedAtUtc, isNull);
    });

    test('itemById finds an item, or null', () {
      expect(template.itemById(13), isA<EvaluationYesNoItem>());
      expect(template.itemById(99), isNull);
    });

    test('round-trips through toMap and toJson', () {
      expect(template.toMap(), templatePayload());
      expect(EvaluationTemplate.fromMap(template.toMap()), template);
      expect(EvaluationTemplate.fromJson(template.toJson()), template);
    });

    test('fromMap reads a soft-deleted template', () {
      final deleted = EvaluationTemplate.fromMap(
        templatePayload()..['deletedAtUtc'] = 3000,
      );
      expect(deleted.deletedAtUtc, isNotNull);
      expect(deleted.copyWith(deletedAtUtc: () => null), template);
    });

    test('copyWith and equality', () {
      expect(template.copyWith(name: 'Other').name, 'Other');
      expect(template.copyWith(), template);
      expect(template.hashCode, template.copyWith().hashCode);
      expect(template, isNot(template.copyWith(layout: const [])));
      expect(
        template,
        isNot(template.copyWith(items: template.items.sublist(1))),
      );
    });
  });
}
