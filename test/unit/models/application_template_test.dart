import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/application_fixtures.dart';

/// Issue 66: application templates (club_server#93).
void main() {
  group('ApplicationTemplate', () {
    test('Issue 66: fromMap reads the metadata of a saved template', () {
      final t = ApplicationTemplate.fromMap(applicationResponseJson());
      expect(t.id, 7);
      expect(t.status, ApplicationStatus.saved);
      expect(t.layout?.name, 'one page');
      expect(t.layout?.spreadWithGuardian, 3.25);
      expect(t.layout?.spreadWithoutGuardian, 6.5);
      expect(t.createdBy, 'test_admin');
      expect(t.createdAtUtc, DateTime.utc(2026));
      expect(t.createdAtUtc.isUtc, isTrue);
      expect(t.updatedAtUtc, DateTime.utc(2026, 1, 1, 1));
    });

    test("Issue 77: a member's read carries the categories they fit", () {
      final t = ApplicationTemplate.fromMap({
        ...applicationResponseJson(status: 'published'),
        'fittingCategories': const [0, 1],
      });
      expect(t.fittingCategories, [0, 1]);
      expect(t.toMap()['fittingCategories'], [0, 1]);
      expect(
        ApplicationTemplate.fromMap(
          applicationResponseJson(),
        ).fittingCategories,
        isNull,
      );
      expect(t, isNot(ApplicationTemplate.fromMap(applicationResponseJson())));
      expect(
        t.copyWith(fittingCategories: () => null).fittingCategories,
        isNull,
      );
      expect(t.toString(), contains('fittingCategories: [0, 1]'));
    });

    test('Issue 81: a published template carries its publishId', () {
      const id = '3f2b9c1e-8a4d-4f6b-9e2a-1c5d7e9f0a1b';
      final json = {
        ...applicationResponseJson(status: 'published'),
        'publishId': id,
      };
      final t = ApplicationTemplate.fromMap(json);
      expect(t.publishId, id);
      expect(t.toMap(), json);
      expect(t.toString(), contains(id));
      expect(t, isNot(t.copyWith(publishId: () => 'another')));
      expect(t.copyWith(publishId: () => null).publishId, isNull);
      expect(t.copyWith(), t);
    });

    test('Issue 81: a draft or saved template has no publishId', () {
      expect(
        ApplicationTemplate.fromMap(emptyDraftResponseJson()).publishId,
        isNull,
      );
      final saved = ApplicationTemplate.fromMap(applicationResponseJson());
      expect(saved.publishId, isNull);
      expect(saved.toMap()['publishId'], isNull);
    });

    test('Issue 66: toMap gives back exactly the JSON it was read from', () {
      final json = applicationResponseJson();
      expect(ApplicationTemplate.fromMap(json).toMap(), json);
    });

    test('Issue 66: an empty draft round-trips, layout and texts null', () {
      final json = emptyDraftResponseJson();
      final t = ApplicationTemplate.fromMap(json);
      expect(t.status, ApplicationStatus.draft);
      expect(t.layout, isNull);
      expect(t.content.title, isNull);
      expect(t.content.languages, ['en']);
      expect(t.content.facts, isEmpty);
      expect(t.toMap(), json);
    });

    test('Issue 66: JSON text survives fromJson / toJson', () {
      final json = applicationResponseJson();
      final t = ApplicationTemplate.fromJson(jsonEncode(json));
      expect(jsonDecode(t.toJson()), json);
      expect(ApplicationTemplate.fromJson(t.toJson()), t);
    });

    test('Issue 66: a server that leaves out createdBy and the content keys '
        'still reads, with the server defaults', () {
      final t = ApplicationTemplate.fromMap(const {
        'id': 1,
        'status': 'draft',
        'createdAtUtc': 0,
        'updatedAtUtc': 0,
      });
      expect(t.createdBy, isNull);
      expect(t.content, const ApplicationContent());
    });

    test('Issue 66: equality and hashCode follow the content', () {
      final a = ApplicationTemplate.fromMap(applicationResponseJson());
      final b = ApplicationTemplate.fromMap(applicationResponseJson());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(ApplicationTemplate.fromMap(applicationResponseJson(id: 9))),
      );
      final changed = applicationResponseJson();
      (changed['facts'] as Map)['fee'] = {'type': 'amount', 'value': 1};
      expect(a, isNot(ApplicationTemplate.fromMap(changed)));
    });

    test('Issue 66: copyWith replaces the status and clears the layout', () {
      final t = ApplicationTemplate.fromMap(applicationResponseJson());
      final reverted = t.copyWith(
        status: ApplicationStatus.draft,
        layout: () => null,
      );
      expect(reverted.status, ApplicationStatus.draft);
      expect(reverted.layout, isNull);
      expect(reverted.content, t.content);
      expect(t.copyWith(), t);
    });
  });

  group('ApplicationStatus', () {
    test('Issue 66: wire values in both directions', () {
      expect(ApplicationStatus.values.map((s) => s.wireName), [
        'draft',
        'saved',
        'published',
      ]);
      for (final s in ApplicationStatus.values) {
        expect(ApplicationStatus.fromWire(s.wireName), s);
      }
      expect(ApplicationStatus.fromWire('archived'), ApplicationStatus.draft);
    });
  });

  group('ApplicationLayout', () {
    test('Issue 66: reads whole-number spreads as doubles', () {
      final layout = ApplicationLayout.fromMap(const {
        'name': 'signing part on page 2',
        'spread': {'withGuardian': 0, 'withoutGuardian': 12},
      });
      expect(layout.spreadWithGuardian, 0.0);
      expect(layout.spreadWithoutGuardian, 12.0);
      expect(layout.toMap(), {
        'name': 'signing part on page 2',
        'spread': {'withGuardian': 0.0, 'withoutGuardian': 12.0},
      });
      expect(ApplicationLayout.fromMap(layout.toMap()), layout);
    });
  });
}
