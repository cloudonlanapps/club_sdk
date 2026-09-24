import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Section 0: Endpoint contract.
///
/// Every endpoint the SDK calls is a string literal in
/// `lib/remote_store/endpoints/`. Nothing else compares those against the
/// server, so a route the server renames or never built simply 404s at
/// runtime inside whichever call happens to use it — which is how five
/// endpoints came to address paths that have never existed.
///
/// These tests read the live OpenAPI schema and compare it against the
/// endpoint sources, in both directions.
void main() {
  group('Section 0: Endpoint contract', () {
    late Set<String> serverPaths;

    /// Server routes the SDK deliberately does not wrap. Listed explicitly so
    /// a NEW gap fails this test rather than joining a silent backlog. Each
    /// entry needs a reason.
    const uncoveredByDesign = <String, String>{
      '/': 'infrastructure, not API surface',
      '/health': 'infrastructure, not API surface',
      '/static/images/coaches/{}': 'static asset, served directly',
      '/v1/media/by_id/{}/encrypt':
          'super-admin encrypt-in-place backfill (club_server#285); operator '
          'tooling exposed through the admin CLI, not an app SDK',
    };

    setUpAll(() async {
      // baseUrl carries a /v1 suffix; the schema is served from the origin.
      final origin = baseUrl.endsWith('/v1')
          ? baseUrl.substring(0, baseUrl.length - '/v1'.length)
          : baseUrl;
      final response = await http.get(Uri.parse('$origin/openapi.json'));
      expect(
        response.statusCode,
        200,
        reason: 'could not read the OpenAPI schema from $origin',
      );
      final schema = json.decode(response.body) as Map<String, dynamic>;
      final paths = schema['paths'] as Map<String, dynamic>;
      serverPaths = paths.keys.map(_normalise).toSet();
      expect(
        serverPaths.length,
        greaterThan(50),
        reason: 'schema looks truncated: ${serverPaths.length} paths',
      );
    });

    test('0.01: every SDK endpoint resolves to a real server route', () {
      final sites = _endpointCallSites();
      final dead = <String, List<String>>{};
      for (final entry in sites.entries) {
        final matched = serverPaths.any((p) => _matches(entry.key, p));
        if (!matched) dead[entry.key] = entry.value;
      }
      expect(
        dead,
        isEmpty,
        reason: 'SDK endpoints with no server route:\n${_describe(dead)}',
      );
    });

    test('0.02: every server route is wrapped, or skipped with a reason', () {
      final sites = _endpointCallSites().keys.toSet();
      final missing =
          serverPaths
              .where((p) => !uncoveredByDesign.containsKey(p))
              .where((p) => !sites.any((c) => _matches(c, p)))
              .toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'server routes with no SDK endpoint (wrap them, or add to '
            'uncoveredByDesign with a reason):\n'
            '${missing.map((p) => '  $p').join('\n')}',
      );
    });

    test('0.03: the skip list names only routes the server still serves', () {
      // A skip for a route that no longer exists is stale bookkeeping; it
      // would otherwise mask the route's disappearance forever.
      final stale = uncoveredByDesign.keys
          .where((p) => !serverPaths.any((s) => _matches(p, s)))
          .toList();
      expect(
        stale,
        isEmpty,
        reason: 'skip list names non-existent routes: $stale',
      );
    });

    test('0.04: the endpoint scanner finds call sites', () {
      // A scanner whose regex silently matches nothing would make 0.01 pass
      // vacuously.
      expect(_endpointCallSites().length, greaterThan(50));
    });
  });
}

/// Collapse path parameters so `{venue_id}` and `{id}` compare equal.
String _normalise(String path) {
  final withoutQuery = path.split('?').first;
  final trimmed = withoutQuery.endsWith('/') && withoutQuery.length > 1
      ? withoutQuery.substring(0, withoutQuery.length - 1)
      : withoutQuery;
  return trimmed.replaceAll(RegExp(r'\{[^}]+\}'), '{}');
}

/// Compare segment-wise, treating `{}` as a single-segment wildcard.
///
/// The wildcard applies on both sides: the server templates its ids, and the
/// SDK templates the owner collection too — one media endpoint serves venues,
/// groups, events and users.
bool _matches(String a, String b) {
  final x = a.split('/');
  final y = b.split('/');
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i] && x[i] != '{}' && y[i] != '{}') return false;
  }
  return true;
}

/// Renders dead endpoints with the source sites that declare them.
String _describe(Map<String, List<String>> dead) => dead.entries
    .map((e) => '  ${e.key}\n      ${e.value.join(', ')}')
    .join('\n');

/// Every path literal in `lib/remote_store/endpoints/`, mapped to the
/// `file:line` sites that declare it.
Map<String, List<String>> _endpointCallSites() {
  // `dart test` runs from the package root.
  final dir = Directory('${Directory.current.path}/lib/remote_store/endpoints');
  final sites = <String, List<String>>{};
  final literal = RegExp("'(/[^']*)'");
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final name = file.uri.pathSegments.last;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final m in literal.allMatches(lines[i])) {
        final raw = m
            .group(1)!
            .replaceAll(RegExp(r'\$\{[^}]+\}'), '{}')
            .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '{}');
        // Endpoint files hold paths relative to the /v1 prefix.
        sites
            .putIfAbsent(_normalise('/v1$raw'), () => [])
            .add('$name:${i + 1}');
      }
    }
  }
  return sites;
}
