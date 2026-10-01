import 'dart:convert';

import 'package:meta/meta.dart';

/// One file attached to an answer as evidence (club_server#535, R56a): an
/// image, a video or a PDF, linked under the item's id as its media tag
/// (see `EvaluationMediaTags.evidence`).
@immutable
class EvaluationEvidence {
  const EvaluationEvidence({required this.mediaUuid, this.metadata});

  factory EvaluationEvidence.fromMap(Map<String, dynamic> map) {
    return EvaluationEvidence(
      mediaUuid: map['mediaUuid'] as String,
      metadata: map['metadata'] as String?,
    );
  }

  factory EvaluationEvidence.fromJson(String source) =>
      EvaluationEvidence.fromMap(json.decode(source) as Map<String, dynamic>);

  final String mediaUuid;

  /// The link's free-form metadata, if any.
  final String? metadata;

  EvaluationEvidence copyWith({
    String? mediaUuid,
    String? Function()? metadata,
  }) {
    return EvaluationEvidence(
      mediaUuid: mediaUuid ?? this.mediaUuid,
      metadata: metadata != null ? metadata() : this.metadata,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mediaUuid': mediaUuid,
    'metadata': metadata,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationEvidence(mediaUuid: $mediaUuid, metadata: $metadata)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationEvidence &&
        other.mediaUuid == mediaUuid &&
        other.metadata == metadata;
  }

  @override
  int get hashCode => mediaUuid.hashCode ^ metadata.hashCode;
}
