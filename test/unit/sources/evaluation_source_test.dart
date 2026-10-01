import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/evaluation_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

/// A [RemoteEvaluationSource] over a mock client that records each request
/// and answers with [respond].
({RemoteEvaluationSource source, List<http.Request> requests})
evaluationHarness(http.Response Function(http.Request request) respond) {
  final requests = <http.Request>[];
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    maxRetries: 0,
  );
  return (source: RemoteEvaluationSource(store), requests: requests);
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

Map<String, dynamic> page(List<Map<String, dynamic>> items) => {
  'items': items,
  'total': items.length,
  'offset': 0,
  'limit': 20,
};

void main() {
  group('Issue 98: RemoteEvaluationSource evaluations', () {
    test('createEvaluation sends template, member, event and period', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload(), 201));

      final view = await h.source.createEvaluation(
        templateId: 5,
        createdFor: 'member1',
        eventId: 9,
        periodStartUtc: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        periodEndUtc: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
      );

      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/evaluations');
      expect(bodyOf(r), {
        'templateId': 5,
        'createdFor': 'member1',
        'eventId': 9,
        'periodStartUtc': 3000,
        'periodEndUtc': 4000,
      });
      expect(view.id, 21);
    });

    test('createEvaluation for a general evaluation sends no event or '
        'period', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload(), 201));

      await h.source.createEvaluation(templateId: 5, createdFor: 'member1');

      expect(bodyOf(h.requests.single), {
        'templateId': 5,
        'createdFor': 'member1',
      });
    });

    test('listEvaluations sends the filters', () async {
      final h = evaluationHarness(
        (_) => jsonResponse(page([staffViewPayload()])),
      );

      final list = await h.source.listEvaluations(
        status: EvaluationStatus.saved,
        createdFor: 'member1',
        eventId: 9,
        general: false,
        offset: 20,
        limit: 10,
      );

      final q = h.requests.single.url.queryParameters;
      expect(h.requests.single.url.path, '/v1/evaluations');
      expect(q, {
        'offset': '20',
        'limit': '10',
        'status': 'saved',
        'createdFor': 'member1',
        'eventId': '9',
        'general': 'false',
      });
      expect(list.items.single.createdFor, 'member1');
    });

    test('listEvaluations omits filters not given', () async {
      final h = evaluationHarness((_) => jsonResponse(page([])));

      await h.source.listEvaluations();

      expect(h.requests.single.url.queryParameters, {
        'offset': '0',
        'limit': '20',
      });
    });

    test('updateEvaluationPeriod sends both bounds', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload()));

      await h.source.updateEvaluationPeriod(
        21,
        periodStartUtc: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        periodEndUtc: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
      );

      final r = h.requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, '/v1/evaluations/by_id/21');
      expect(bodyOf(r), {'periodStartUtc': 3000, 'periodEndUtc': 4000});
    });

    test(
      'updateEvaluationPeriod clears the period with explicit nulls',
      () async {
        final h = evaluationHarness((_) => jsonResponse(staffViewPayload()));

        await h.source.updateEvaluationPeriod(
          21,
          periodStartUtc: null,
          periodEndUtc: null,
        );

        expect(bodyOf(h.requests.single), {
          'periodStartUtc': null,
          'periodEndUtc': null,
        });
      },
    );

    test('putAnswer PUTs the answer to the item', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload()));

      final view = await h.source.putAnswer(
        21,
        11,
        const EvaluationAnswerInput(valueNum: 4, coachNote: 'Good edges'),
      );

      final r = h.requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, '/v1/evaluations/by_id/21/answers/11');
      expect(bodyOf(r), {'valueNum': 4, 'coachNote': 'Good edges'});
      expect(view.answerFor(11)?.valueNum, 4);
    });

    test('clearAnswer DELETEs the answer and reads the evaluation', () async {
      final h = evaluationHarness(
        (_) => jsonResponse(staffViewPayload()..['answers'] = <dynamic>[]),
      );

      final view = await h.source.clearAnswer(21, 11);

      final r = h.requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, '/v1/evaluations/by_id/21/answers/11');
      expect(view.answers, isEmpty);
    });

    test('transferEvaluation sends the owner and takes a 204', () async {
      final h = evaluationHarness((_) => http.Response('', 204));

      await h.source.transferEvaluation(21, owner: 'coach2');

      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/evaluations/by_id/21/transfer');
      expect(bodyOf(r), {'owner': 'coach2'});
    });

    test('previewMemberCopy returns the PDF bytes', () async {
      final pdf = utf8.encode('%PDF-1.7');
      final h = evaluationHarness(
        (_) => http.Response.bytes(
          pdf,
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      );

      final bytes = await h.source.previewMemberCopy(21);

      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/evaluations/by_id/21/pdf');
      expect(bytes, pdf);
    });

    test('a 422 INCOMPLETE on save carries the item ids', () async {
      final h = evaluationHarness(
        (_) => jsonResponse({
          'detail': {
            'code': 'INCOMPLETE',
            'message': 'incomplete',
            'details': {
              'itemIds': [11, 13],
            },
          },
        }, 422),
      );

      await expectLater(
        h.source.saveEvaluation(21),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', SdkErrorCode.incomplete)
              .having(
                (e) => (e.details?['details'] as Map?)?['itemIds'],
                'itemIds',
                [11, 13],
              ),
        ),
      );
      expect(h.requests.single.url.path, '/v1/evaluations/by_id/21/save');
    });
  });

  group('Issue 98: RemoteEvaluationSource.uploadEvidence', () {
    Matcher throwsCode(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    http.Response errorResponse(int status, String code) => jsonResponse({
      'detail': {'code': code, 'message': code},
    }, status);

    test('POSTs the file as multipart field "file" to the item and reads '
        'the evaluation', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload(), 201));

      final view = await h.source.uploadEvidence(
        21,
        11,
        bytes: const [1, 2, 3, 4],
        filename: 'clip.png',
        contentType: 'image/png',
      );

      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/evaluations/by_id/21/evidence/11');
      expect(r.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(r.bodyBytes);
      expect(body, contains('name="file"; filename="clip.png"'));
      expect(body.toLowerCase(), contains('content-type: image/png'));
      expect(body, contains(latin1.decode(const [1, 2, 3, 4])));
      expect(view.id, 21);
      expect(view.answerFor(11)?.evidence.single.mediaUuid, 'm1');
    });

    test('sends no content type when none is given', () async {
      final h = evaluationHarness((_) => jsonResponse(staffViewPayload(), 201));

      await h.source.uploadEvidence(
        21,
        11,
        bytes: const [1],
        filename: 'notes.pdf',
      );

      final body = latin1.decode(h.requests.single.bodyBytes);
      expect(body, contains('filename="notes.pdf"'));
      expect(
        body.toLowerCase(),
        isNot(contains('content-type: application/pdf')),
      );
    });

    final errors = <(int, String)>[
      (422, SdkErrorCode.invalidEvidence),
      (422, SdkErrorCode.invalidState),
      (404, SdkErrorCode.evaluationNotFound),
      (413, SdkErrorCode.fileTooLarge),
    ];
    for (final (status, code) in errors) {
      test('a $status $code surfaces as a ServerException and is sent '
          'once', () async {
        final h = evaluationHarness((_) => errorResponse(status, code));

        await expectLater(
          h.source.uploadEvidence(
            21,
            11,
            bytes: const [1],
            filename: 'clip.png',
            contentType: 'image/png',
          ),
          throwsCode(status, code),
        );
        expect(h.requests, hasLength(1));
      });
    }
  });

  group('Issue 98: RemoteEvaluationSource templates', () {
    test(
      'createTemplate sends name and the layout with items inline',
      () async {
        final h = evaluationHarness(
          (_) => jsonResponse(templatePayload(), 201),
        );
        final info = EvaluationTemplateItem.fromMap(infoItemPayload());
        final rating = EvaluationTemplateItem.fromMap(ratingItemPayload());

        final template = await h.source.createTemplate(
          name: 'Term review',
          layout: [
            EvaluationLayoutItem(info),
            EvaluationLayoutSection('Skills', [rating]),
          ],
        );

        final r = h.requests.single;
        expect(r.method, 'POST');
        expect(r.url.path, '/v1/evaluations/templates');
        expect(bodyOf(r), {
          'name': 'Term review',
          'layout': [
            infoItemPayload(),
            {
              'section': 'Skills',
              'items': [ratingItemPayload()],
            },
          ],
        });
        expect(template.items, hasLength(3));
      },
    );

    test('updateTemplate sends only what is given', () async {
      final h = evaluationHarness((_) => jsonResponse(templatePayload()));

      await h.source.updateTemplate(5, name: 'Renamed');
      await h.source.updateTemplate(
        5,
        layout: const [
          EvaluationLayoutSection('Skills', [13, 11]),
          EvaluationLayoutItem(18),
        ],
      );

      expect(h.requests[0].method, 'PATCH');
      expect(h.requests[0].url.path, '/v1/evaluations/templates/by_id/5');
      expect(bodyOf(h.requests[0]), {'name': 'Renamed'});
      expect(bodyOf(h.requests[1]), {
        'layout': [
          {
            'section': 'Skills',
            'items': [13, 11],
          },
          18,
        ],
      });
    });

    test('addItem POSTs the item and an optional section', () async {
      final h = evaluationHarness((_) => jsonResponse(templatePayload(), 201));
      final qa = EvaluationTemplateItem.fromMap(qaItemPayload());

      await h.source.addItem(5, qa, section: 'Skills');
      await h.source.addItem(5, qa);

      expect(h.requests[0].method, 'POST');
      expect(h.requests[0].url.path, '/v1/evaluations/templates/by_id/5/items');
      expect(bodyOf(h.requests[0]), {
        'item': qaItemPayload(),
        'section': 'Skills',
      });
      expect(bodyOf(h.requests[1]), {'item': qaItemPayload()});
    });

    test('replaceItem PUTs the whole variant', () async {
      final h = evaluationHarness((_) => jsonResponse(templatePayload()));
      final rating =
          EvaluationTemplateItem.fromMap(ratingItemPayload())
              as EvaluationRatingItem;

      await h.source.replaceItem(5, 11, rating.copyWith(question: 'Edges'));

      final r = h.requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, '/v1/evaluations/templates/by_id/5/items/11');
      expect(bodyOf(r), ratingItemPayload()..['question'] = 'Edges');
    });

    test('removeItem DELETEs the item and reads the template', () async {
      final h = evaluationHarness((_) => jsonResponse(templatePayload()));

      final template = await h.source.removeItem(5, 11);

      final r = h.requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, '/v1/evaluations/templates/by_id/5/items/11');
      expect(template.id, 5);
    });

    test('searchItems sends the text and type', () async {
      final h = evaluationHarness(
        (_) => jsonResponse(
          page([
            {
              'templateId': 5,
              'templateName': 'Term review',
              'item': ratingItemPayload(),
            },
          ]),
        ),
      );

      final hits = await h.source.searchItems(
        search: 'skat',
        type: EvaluationItemType.rating,
      );

      final r = h.requests.single;
      expect(r.url.path, '/v1/evaluations/templates/items');
      expect(r.url.queryParameters, {
        'offset': '0',
        'limit': '20',
        'search': 'skat',
        'type': 'rating',
      });
      expect(hits.items.single.item, isA<EvaluationRatingItem>());
    });
  });
}
