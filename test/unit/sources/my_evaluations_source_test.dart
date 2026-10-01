import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/my_evaluations_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  RemoteMyEvaluationsSource sourceAnswering(Object body) =>
      RemoteMyEvaluationsSource(
        RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

  group('Issue 98: RemoteMyEvaluationsSource', () {
    test('getMyEvaluation reads the member projection', () async {
      final view = await sourceAnswering(
        memberViewPayload(),
      ).getMyEvaluation('member1', 21);

      expect(view.template.items.single, isA<EvaluationRatingItem>());
      expect(view.answers.single.itemId, 11);
    });

    test('listMyEvaluationMedia groups evidence and the member copy', () async {
      Map<String, dynamic> link(String tag, String uuid) => {
        'tag': tag,
        'metadata': null,
        'media': {'uuid': uuid, 'mimeType': 'image/webp', 'filename': uuid},
        'createdAtUtc': 1000,
        'updatedAtUtc': 1000,
      };

      final media = await sourceAnswering({
        '11': [link('11', 'm1')],
        'member_copy': [link('member_copy', 'pdf1')],
      }).listMyEvaluationMedia('member1', 21);

      expect(media[EvaluationMediaTags.evidence(11)]!.single.mediaUuid, 'm1');
      expect(
        media[EvaluationMediaTags.memberCopy]!.single.mediaUuid,
        'pdf1',
      );
    });
  });
}
