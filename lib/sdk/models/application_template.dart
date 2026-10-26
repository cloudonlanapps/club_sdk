import 'dart:convert';

import 'package:meta/meta.dart';

import 'application_content.dart';
import 'application_layout.dart';
import 'application_status.dart';

/// An application template (club_server#93): what an admin wrote
/// ([content]), where it is in its lifecycle ([status]) and, once saved,
/// how its form is fitted ([layout]).
///
/// [toMap] gives back the server's JSON: the content keys at the top
/// level beside `id`, `status`, `layout`, `createdBy`, `createdAtUtc` and
/// `updatedAtUtc`.
@immutable
class ApplicationTemplate {
  const ApplicationTemplate({
    required this.id,
    required this.status,
    required this.content,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.layout,
    this.createdBy,
  });

  factory ApplicationTemplate.fromMap(Map<String, dynamic> map) {
    final layout = map['layout'];
    return ApplicationTemplate(
      id: map['id'] as int,
      status: ApplicationStatus.fromWire(map['status'] as String),
      content: ApplicationContent.fromMap(map),
      layout: layout is Map<String, dynamic>
          ? ApplicationLayout.fromMap(layout)
          : null,
      createdBy: map['createdBy'] as String?,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  factory ApplicationTemplate.fromJson(String source) =>
      ApplicationTemplate.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;

  /// Draft, saved or published.
  final ApplicationStatus status;

  /// Everything the admin wrote.
  final ApplicationContent content;

  /// Set on save, dropped on revert: null for a draft.
  final ApplicationLayout? layout;

  /// Username of the admin who created it.
  final String? createdBy;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  ApplicationTemplate copyWith({
    int? id,
    ApplicationStatus? status,
    ApplicationContent? content,
    ApplicationLayout? Function()? layout,
    String? Function()? createdBy,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return ApplicationTemplate(
      id: id ?? this.id,
      status: status ?? this.status,
      content: content ?? this.content,
      layout: layout != null ? layout() : this.layout,
      createdBy: createdBy != null ? createdBy() : this.createdBy,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toMap() => {
    ...content.toMap(),
    'id': id,
    'status': status.wireName,
    'layout': layout?.toMap(),
    'createdBy': createdBy,
    'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ApplicationTemplate(id: $id, status: ${status.wireName}, '
      'layout: $layout)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationTemplate &&
          other.id == id &&
          other.status == status &&
          other.content == content &&
          other.layout == layout &&
          other.createdBy == createdBy &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    status,
    content,
    layout,
    createdBy,
    createdAtUtc,
    updatedAtUtc,
  );
}
