import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationEvidence', () {
    const evidence = EvaluationEvidence(mediaUuid: 'm1', metadata: 'clip');

    test('round-trips through toMap and toJson', () {
      expect(evidence.toMap(), {'mediaUuid': 'm1', 'metadata': 'clip'});
      expect(EvaluationEvidence.fromMap(evidence.toMap()), evidence);
      expect(EvaluationEvidence.fromJson(evidence.toJson()), evidence);
    });

    test('fromMap reads a missing metadata as null', () {
      expect(
        EvaluationEvidence.fromMap(const {'mediaUuid': 'm1'}).metadata,
        isNull,
      );
    });

    test('copyWith clears metadata, and equality', () {
      expect(evidence.copyWith(metadata: () => null).metadata, isNull);
      expect(evidence.copyWith(), evidence);
      expect(evidence.hashCode, evidence.copyWith().hashCode);
      expect(evidence, isNot(evidence.copyWith(mediaUuid: 'm2')));
    });
  });
}
