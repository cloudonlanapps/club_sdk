import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

const _mapEquality = MapEquality<String, dynamic>();
const _stringMapEquality = MapEquality<String, String>();

/// A user referenced by an audit row (the actor or the target).
///
/// [fullName] is the name resolved server-side at query time and is preserved
/// even after the referent is soft-deleted — an audit log records what
/// happened in the past.
@immutable
class AuditUserRef {
  const AuditUserRef({required this.username, this.fullName});

  factory AuditUserRef.fromMap(Map<String, dynamic> map) {
    return AuditUserRef(
      username: map['username'] as String,
      fullName: map['fullName'] as String?,
    );
  }

  final String username;
  final String? fullName;

  /// `fullName` when present, otherwise the bare `username`.
  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : username;

  @override
  bool operator ==(Object other) =>
      other is AuditUserRef &&
      other.username == username &&
      other.fullName == fullName;

  @override
  int get hashCode => Object.hash(username, fullName);
}

/// A single audit-log row, with foreign keys resolved to names server-side.
///
/// [resource] and [details] are intentionally free-form maps because their
/// shape varies by action / resource type (see the server's `AuditLogRow`):
///   - generic resource: `{type, id, label}`
///   - occurrence resource: `{type, eventId, eventTitle, occurrenceTimeUtc}`
///   - unknown resource: `{type, id, label: null}`
///
/// [summary] is a per-language map of ready-to-render sentences (e.g.
/// `{"en": "Asha cancelled event U10 Practice on 2026-06-01 13:30 UTC."}`),
/// rendered at query time by the server. Prefer it for display.
@immutable
class AuditLogRow {
  const AuditLogRow({
    required this.id,
    required this.timestampUtc,
    required this.action,
    required this.summary,
    this.actor,
    this.target,
    this.resource,
    this.details,
  });

  factory AuditLogRow.fromMap(Map<String, dynamic> map) {
    final actorMap = map['actor'] as Map<String, dynamic>?;
    final targetMap = map['target'] as Map<String, dynamic>?;
    final summaryRaw = (map['summary'] as Map?) ?? const <String, dynamic>{};
    return AuditLogRow(
      id: map['id'] as int,
      timestampUtc: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
        isUtc: true,
      ),
      action: map['action'] as String,
      actor: actorMap == null ? null : AuditUserRef.fromMap(actorMap),
      target: targetMap == null ? null : AuditUserRef.fromMap(targetMap),
      resource: (map['resource'] as Map?)?.cast<String, dynamic>(),
      details: (map['details'] as Map?)?.cast<String, dynamic>(),
      summary: summaryRaw.map((k, v) => MapEntry(k as String, v as String)),
    );
  }

  final int id;
  final DateTime timestampUtc;
  final String action;
  final AuditUserRef? actor;
  final AuditUserRef? target;
  final Map<String, dynamic>? resource;
  final Map<String, dynamic>? details;
  final Map<String, String> summary;

  /// The English summary sentence, or `null` when the server emitted none.
  String? get summaryEn => summary['en'];

  @override
  bool operator ==(Object other) =>
      other is AuditLogRow &&
      other.id == id &&
      other.timestampUtc == timestampUtc &&
      other.action == action &&
      other.actor == actor &&
      other.target == target &&
      _mapEquality.equals(other.resource, resource) &&
      _mapEquality.equals(other.details, details) &&
      _stringMapEquality.equals(other.summary, summary);

  @override
  int get hashCode => Object.hash(
    id,
    timestampUtc,
    action,
    actor,
    target,
    _mapEquality.hash(resource),
    _mapEquality.hash(details),
    _stringMapEquality.hash(summary),
  );
}

/// A page of audit rows plus pagination metadata.
///
/// The audit endpoint returns `rows` (not `items`), so this is a dedicated
/// model rather than the generic `PaginatedList`.
@immutable
class AuditLogPage {
  const AuditLogPage({
    required this.total,
    required this.offset,
    required this.limit,
    required this.rows,
  });

  factory AuditLogPage.fromMap(Map<String, dynamic> map) {
    return AuditLogPage(
      total: map['total'] as int,
      offset: map['offset'] as int,
      limit: map['limit'] as int,
      rows: (map['rows'] as List)
          .map((e) => AuditLogRow.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int total;
  final int offset;
  final int limit;
  final List<AuditLogRow> rows;

  /// Whether more rows exist beyond this page.
  bool get hasMore => offset + rows.length < total;
}
