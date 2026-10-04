import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

int readId(Object? wire) => (wire! as num).toInt();
Object? writeId(int id) => id;

void main() {
  group('Issue 98: EvaluationLayoutEntry of item ids', () {
    test('a bare id reads as an item entry', () {
      final entry = EvaluationLayoutEntry<int>.fromWire(18, readId);
      expect(entry, const EvaluationLayoutItem<int>(18));
      expect(entry.items, [18]);
      expect(entry.toWire(writeId), 18);
    });

    test('a section reads with its title and ids', () {
      final entry = EvaluationLayoutEntry<int>.fromWire(const {
        'section': 'Skills',
        'items': [11, 13],
      }, readId);
      expect(entry, isA<EvaluationLayoutSection<int>>());
      final section = entry as EvaluationLayoutSection<int>;
      expect(section.section, 'Skills');
      expect(section.items, [11, 13]);
      expect(section.toWire(writeId), {
        'section': 'Skills',
        'items': [11, 13],
      });
    });

    test('section round-trips through toMap and fromMap', () {
      const section = EvaluationLayoutSection<int>('Skills', [11, 13]);
      expect(
        EvaluationLayoutSection<int>.fromMap(section.toMap(writeId), readId),
        section,
      );
    });

    test('copyWith and equality', () {
      const section = EvaluationLayoutSection<int>('Skills', [11, 13]);
      expect(section.copyWith(section: 'Play').section, 'Play');
      expect(section.copyWith(items: [13]).items, [13]);
      expect(section.copyWith(), section);
      expect(section.hashCode, section.copyWith().hashCode);
      expect(section, isNot(section.copyWith(items: [13, 11])));
      const item = EvaluationLayoutItem<int>(18);
      expect(item.copyWith(item: 19).item, 19);
      expect(item.copyWith(), item);
      expect(item.hashCode, const EvaluationLayoutItem<int>(18).hashCode);
    });
  });

  group('Issue 98: EvaluationLayoutEntry of new items', () {
    final rating = EvaluationTemplateItem.fromMap(ratingItemPayload());
    final info = EvaluationTemplateItem.fromMap(infoItemPayload());

    test('an inline item writes as the item itself', () {
      final entry = EvaluationLayoutItem<EvaluationTemplateItem>(info);
      expect(entry.toWire((i) => i.toMap()), infoItemPayload());
    });

    test('a section writes its items inline', () {
      final entry = EvaluationLayoutSection<EvaluationTemplateItem>('Skills', [
        rating,
      ]);
      expect(entry.toWire((i) => i.toMap()), {
        'section': 'Skills',
        'items': [ratingItemPayload()],
      });
    });

    test('an inline item map is not mistaken for a section', () {
      final entry = EvaluationLayoutEntry<EvaluationTemplateItem>.fromWire(
        infoItemPayload(),
        (w) => EvaluationTemplateItem.fromMap(w! as Map<String, dynamic>),
      );
      expect(entry, EvaluationLayoutItem<EvaluationTemplateItem>(info));
    });
  });
}
