import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/application_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../../utils/application_fixtures.dart';

/// Issue 66: `RemoteApplicationSource` against a stubbed HTTP client
/// (club_server#93).
({RemoteApplicationSource source, List<http.Request> requests}) harness({
  Object? body,
  List<int>? bytes,
  int status = 200,
}) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    if (bytes != null) {
      return http.Response.bytes(
        bytes,
        status,
        headers: {'content-type': 'application/pdf'},
      );
    }
    return http.Response(
      jsonEncode(body ?? applicationResponseJson()),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
    maxRetries: 0,
  );
  return (source: RemoteApplicationSource(store), requests: requests);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  const pdf = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-

  group('RemoteApplicationSource templates', () {
    test('Issue 66: createApplication POSTs the whole content', () async {
      final h = harness(body: applicationResponseJson(status: 'draft'));
      final created = await h.source.createApplication(
        ApplicationContent.fromMap(applicationContentJson()),
      );
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/applications');
      expect(bodyOf(r), applicationContentJson());
      expect(created.status, ApplicationStatus.draft);
      expect(created.id, 7);
    });

    test('Issue 66: listApplications sends paging and the status', () async {
      final h = harness(
        body: {
          'items': [applicationResponseJson(), emptyDraftResponseJson()],
          'total': 12,
          'offset': 10,
          'limit': 2,
        },
      );
      final page = await h.source.listApplications(
        status: ApplicationStatus.published,
        offset: 10,
        limit: 2,
      );
      final r = h.requests.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/v1/applications');
      expect(r.url.queryParameters, {
        'offset': '10',
        'limit': '2',
        'status': 'published',
      });
      expect(page.items.map((t) => t.id), [7, 8]);
      expect(page.total, 12);
      expect(page.hasMore, isFalse);
    });

    test('Issue 66: listApplications without a status sends none', () async {
      final h = harness(
        body: {'items': <dynamic>[], 'total': 0, 'offset': 0, 'limit': 20},
      );
      await h.source.listApplications();
      expect(h.requests.single.url.queryParameters, {
        'offset': '0',
        'limit': '20',
      });
    });

    test('Issue 66: getApplication GETs one template', () async {
      final h = harness();
      final t = await h.source.getApplication(7);
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/applications/7');
      expect(t.toMap(), applicationResponseJson());
    });

    test('Issue 66: updateApplication PATCHes only the patch', () async {
      final h = harness(body: applicationResponseJson(status: 'draft'));
      await h.source.updateApplication(
        7,
        ApplicationPatch(
          formFooter: () => null,
          selections: () => const [
            ApplicationText({'en': 'Yes'}),
          ],
        ),
      );
      final r = h.requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, '/v1/applications/7');
      expect(bodyOf(r), {
        'formFooter': null,
        'selections': [
          {'en': 'Yes'},
        ],
      });
    });

    test(
      'Issue 66: deleteApplication DELETEs and returns the template',
      () async {
        final h = harness(body: applicationResponseJson(status: 'draft'));
        final deleted = await h.source.deleteApplication(7);
        expect(h.requests.single.method, 'DELETE');
        expect(h.requests.single.url.path, '/v1/applications/7');
        expect(deleted.id, 7);
      },
    );

    final moves =
        <String, Future<ApplicationTemplate> Function(ApplicationSource, int)>{
          'save': (s, id) => s.saveApplication(id),
          'publish': (s, id) => s.publishApplication(id),
          'unpublish': (s, id) => s.unpublishApplication(id),
          'revert': (s, id) => s.revertApplication(id),
          'duplicate': (s, id) => s.duplicateApplication(id),
        };
    for (final move in moves.entries) {
      test('Issue 66: ${move.key} POSTs /applications/{id}/${move.key} '
          'with no body', () async {
        final h = harness();
        final t = await move.value(h.source, 7);
        final r = h.requests.single;
        expect(r.method, 'POST');
        expect(r.url.path, '/v1/applications/7/${move.key}');
        expect(r.body, isEmpty);
        expect(t.id, 7);
      });
    }
  });

  group('RemoteApplicationSource PDFs', () {
    test('Issue 66: downloadPreview GETs the preview bytes', () async {
      final h = harness(bytes: pdf);
      expect(await h.source.downloadPreview(7), pdf);
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/applications/7/preview');
    });

    test("Issue 66: downloadOwnForm GETs the caller's form", () async {
      final h = harness(bytes: pdf);
      expect(await h.source.downloadOwnForm(7), pdf);
      expect(h.requests.single.url.path, '/v1/applications/7/form');
    });

    test("Issue 66: downloadMemberForm GETs a member's form", () async {
      final h = harness(bytes: pdf);
      expect(await h.source.downloadMemberForm(7, 'test_m1'), pdf);
      expect(h.requests.single.url.path, '/v1/applications/7/form/test_m1');
    });

    test('Issue 94: downloadBlankForm GETs the blank form', () async {
      final h = harness(bytes: pdf);
      expect(await h.source.downloadBlankForm(7), pdf);
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/applications/7/blank-form');
      expect(h.requests.single.url.query, isEmpty);
    });

    test('Issue 77: the form downloads send the chosen category', () async {
      final h = harness(bytes: pdf);
      expect(await h.source.downloadOwnForm(7, category: 1), pdf);
      expect(await h.source.downloadMemberForm(7, 'test_m1', category: 0), pdf);
      expect(h.requests[0].url.path, '/v1/applications/7/form');
      expect(h.requests[0].url.queryParameters, {'category': '1'});
      expect(h.requests[1].url.path, '/v1/applications/7/form/test_m1');
      expect(h.requests[1].url.queryParameters, {'category': '0'});
    });

    test('Issue 77: no category sends no query', () async {
      final h = harness(bytes: pdf);
      await h.source.downloadOwnForm(7);
      await h.source.downloadMemberForm(7, 'test_m1');
      expect(h.requests.map((r) => r.url.query), ['', '']);
    });

    test('Issue 66: a refused download throws the mapped error', () async {
      final h = harness(
        status: 422,
        body: {
          'detail': {
            'code': 'APPLICATION_NOT_ELIGIBLE',
            'message': 'not eligible for this application',
          },
        },
      );
      await expectLater(
        h.source.downloadOwnForm(7),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.applicationNotEligible,
              ),
        ),
      );
    });
  });

  group('RemoteApplicationSource catalogues', () {
    test('Issue 66: getLabels GETs /applications/labels', () async {
      final h = harness(
        body: {
          'languages': ['en'],
          'labels': {
            'field.full_name': {'en': 'Full name'},
          },
        },
      );
      final labels = await h.source.getLabels();
      expect(h.requests.single.url.path, '/v1/applications/labels');
      expect(labels.label('field.full_name', 'en'), 'Full name');
    });

    test('Issue 92: getClauses GETs /applications/clauses and reads the '
        'list of built-in clauses and club texts', () async {
      final h = harness(
        body: {
          'languages': ['en'],
          'choices': <String, dynamic>{},
          'clauses': [
            {
              'source': 'builtin',
              'key': 'note.follow_rules',
              'id': null,
              'kind': 'note',
              'name': null,
              'gaps': <String, dynamic>{},
              'heading': null,
              'text': {'en': 'Follow the rules.'},
            },
            {
              'source': 'club',
              'key': null,
              'id': 3,
              'kind': 'note',
              'name': 'Be on time',
              'gaps': null,
              'heading': null,
              'text': {'en': 'Report by {report_time}.'},
            },
          ],
        },
      );
      final library = await h.source.getClauses();
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/applications/clauses');
      expect(library.clauses.map((c) => c.key), ['note.follow_rules', null]);
      expect(library.clauses.map((c) => c.id), [null, 3]);
      expect(library.clubTexts.single.name, 'Be on time');
    });
  });

  group('RemoteApplicationSource club library', () {
    Map<String, dynamic> textJson({int id = 5, String name = 'Match days'}) =>
        <String, dynamic>{
          'id': id,
          'kind': 'rule',
          'name': name,
          'heading': {'en': 'Matches'},
          'text': {'en': 'On {match_dates}.'},
          'createdBy': 'test_admin',
          'createdAtUtc': 1798761600000,
          'updatedAtUtc': 1798761600000,
        };

    test('Issue 92: listLibraryTexts GETs /applications/library and reads '
        'every text in order', () async {
      final h = harness(
        body: [
          textJson(id: 1, name: 'First'),
          textJson(id: 2, name: 'Second'),
        ],
      );
      final texts = await h.source.listLibraryTexts();
      final r = h.requests.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/v1/applications/library');
      expect(texts.map((t) => t.id), [1, 2]);
      expect(texts.map((t) => t.name), ['First', 'Second']);
    });

    test('Issue 92: getLibraryText GETs one text', () async {
      final h = harness(body: textJson());
      final text = await h.source.getLibraryText(5);
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/v1/applications/library/5');
      expect(text, ApplicationLibraryText.fromMap(textJson()));
    });

    test('Issue 92: createLibraryText POSTs the new text', () async {
      final h = harness(body: textJson(), status: 201);
      final text = await h.source.createLibraryText(
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.rule,
          name: 'Match days',
          heading: ApplicationText({'en': 'Matches'}),
          text: ApplicationText({'en': 'On {match_dates}.'}),
        ),
      );
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/applications/library');
      expect(bodyOf(r), {
        'kind': 'rule',
        'name': 'Match days',
        'heading': {'en': 'Matches'},
        'text': {'en': 'On {match_dates}.'},
      });
      expect(text.id, 5);
    });

    test('Issue 92: updateLibraryText PATCHes only the fields given', () async {
      final h = harness(body: textJson(name: 'Renamed'));
      final text = await h.source.updateLibraryText(
        5,
        ApplicationLibraryTextPatch(name: 'Renamed', heading: () => null),
      );
      final r = h.requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, '/v1/applications/library/5');
      expect(bodyOf(r), {'name': 'Renamed', 'heading': null});
      expect(text.name, 'Renamed');
    });

    test('Issue 92: deleteLibraryText DELETEs the text (204)', () async {
      final h = harness(body: '', status: 204);
      await h.source.deleteLibraryText(5);
      expect(h.requests.single.method, 'DELETE');
      expect(h.requests.single.url.path, '/v1/applications/library/5');
    });

    test('Issue 92: an unknown text is 404 '
        'APPLICATION_LIBRARY_TEXT_NOT_FOUND', () async {
      final h = harness(
        status: 404,
        body: {
          'detail': {
            'code': 'APPLICATION_LIBRARY_TEXT_NOT_FOUND',
            'message': 'Library text 99 not found',
          },
        },
      );
      await expectLater(
        h.source.getLibraryText(99),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.applicationLibraryTextNotFound,
              ),
        ),
      );
    });

    test('Issue 92: saveApplication refused for a gap naming no fact is '
        'ApplicationUnknownFactException', () async {
      final h = harness(
        status: 422,
        body: {
          'detail': {
            'code': 'APPLICATION_UNKNOWN_FACT',
            'message': 'Gaps naming no fact of the template: title (en): x',
            'details': {
              'gaps': [
                {'place': 'title', 'language': 'en', 'gap': 'x'},
              ],
            },
          },
        },
      );
      await expectLater(
        h.source.saveApplication(7),
        throwsA(
          isA<ApplicationUnknownFactException>().having(
            (e) => e.gaps,
            'gaps',
            const [
              ApplicationUnknownGap(place: 'title', language: 'en', gap: 'x'),
            ],
          ),
        ),
      );
    });

    test('Issue 66: the module off is ModuleDisabledException', () async {
      final h = harness(
        status: 503,
        body: {
          'detail': {
            'code': 'APPLICATIONS_DISABLED',
            'message': 'Applications are not enabled on this deployment',
          },
        },
      );
      await expectLater(
        h.source.listApplications(),
        throwsA(
          isA<ModuleDisabledException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.applicationsDisabled,
          ),
        ),
      );
      expect(h.requests, hasLength(1), reason: 'a module-off 503 is final');
    });
  });
}
