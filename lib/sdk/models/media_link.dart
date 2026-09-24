import 'dart:convert';

import 'package:meta/meta.dart';

import 'media_ref.dart';

/// Owner type for per-owner media link tables (#162).
///
/// One of `user`, `event`, `group`, `venue` — the four owners that can
/// attach media via dedicated link tables.
enum MediaLinkOwnerType {
  user('user'),
  event('event'),
  group('group'),
  venue('venue');

  const MediaLinkOwnerType(this.wire);

  /// Wire string used in URL paths and `ownerType` query / response fields.
  final String wire;

  static MediaLinkOwnerType fromWire(String wire) {
    return MediaLinkOwnerType.values.firstWhere(
      (e) => e.wire == wire,
      orElse: () =>
          throw ArgumentError('Unknown MediaLinkOwnerType wire value: $wire'),
    );
  }
}

/// A single link row: what the link says, and the media it points at.
///
/// [media] is the same [MediaRef] every other projection embeds, rather than
/// the same facts flattened under a second set of names — `mediaUuid` for
/// what is `uuid` everywhere else (club_server#426).
@immutable
class MediaLink {
  const MediaLink({
    required this.tag,
    required this.media,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.metadata,
  });

  factory MediaLink.fromMap(Map<String, dynamic> map) {
    return MediaLink(
      tag: map['tag'] as String,
      metadata: map['metadata'] as String?,
      media: MediaRef.fromMap(map['media'] as Map<String, dynamic>),
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

  factory MediaLink.fromJson(String source) =>
      MediaLink.fromMap(json.decode(source) as Map<String, dynamic>);

  final String tag;
  final String? metadata;

  /// The media this link points at.
  final MediaRef media;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// The uuid of the linked media. Shorthand for `media.uuid`.
  String get mediaUuid => media.uuid;

  Map<String, dynamic> toMap() => {
    'tag': tag,
    'metadata': metadata,
    'media': media.toMap(),
    'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'MediaLink(tag: $tag, media: $media, metadata: $metadata)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaLink &&
          other.tag == tag &&
          other.metadata == metadata &&
          other.media == media &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode =>
      Object.hash(tag, metadata, media, createdAtUtc, updatedAtUtc);
}

/// One row from `GET /v1/media/by_id/{uuid}/links` (reverse lookup).
///
/// Does not denormalize media columns since the caller already has the
/// media in hand (they queried by its uuid).
@immutable
class MediaLinkReverseEntry {
  const MediaLinkReverseEntry({
    required this.ownerType,
    required this.ownerId,
    required this.tag,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.metadata,
  });

  factory MediaLinkReverseEntry.fromMap(Map<String, dynamic> map) {
    return MediaLinkReverseEntry(
      ownerType: MediaLinkOwnerType.fromWire(map['ownerType'] as String),
      ownerId: map['ownerId'].toString(),
      tag: map['tag'] as String,
      metadata: map['metadata'] as String?,
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

  final MediaLinkOwnerType ownerType;

  /// `username` for users; stringified int id for events / groups / venues.
  final String ownerId;
  final String tag;
  final String? metadata;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  @override
  String toString() =>
      'MediaLinkReverseEntry(${ownerType.wire}:$ownerId, tag: $tag)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaLinkReverseEntry &&
          other.ownerType == ownerType &&
          other.ownerId == ownerId &&
          other.tag == tag &&
          other.metadata == metadata &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
    ownerType,
    ownerId,
    tag,
    metadata,
    createdAtUtc,
    updatedAtUtc,
  );
}

/// One row from `GET /v1/media/links` (admin/coach cross-owner search).
@immutable
class MediaLinkCrossEntry {
  const MediaLinkCrossEntry({
    required this.mediaUuid,
    required this.ownerType,
    required this.ownerId,
    required this.tag,
    required this.mediaType,
    required this.createdAtUtc,
    this.metadata,
  });

  factory MediaLinkCrossEntry.fromMap(Map<String, dynamic> map) {
    return MediaLinkCrossEntry(
      mediaUuid: map['mediaUuid'] as String,
      ownerType: MediaLinkOwnerType.fromWire(map['ownerType'] as String),
      ownerId: map['ownerId'].toString(),
      tag: map['tag'] as String,
      metadata: map['metadata'] as String?,
      mediaType: map['mediaType'] as String,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  final String mediaUuid;
  final MediaLinkOwnerType ownerType;
  final String ownerId;
  final String tag;
  final String? metadata;
  final String mediaType;
  final DateTime createdAtUtc;

  @override
  String toString() =>
      'MediaLinkCrossEntry(${ownerType.wire}:$ownerId, tag: $tag, '
      'media: $mediaUuid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaLinkCrossEntry &&
          other.mediaUuid == mediaUuid &&
          other.ownerType == ownerType &&
          other.ownerId == ownerId &&
          other.tag == tag &&
          other.metadata == metadata &&
          other.mediaType == mediaType &&
          other.createdAtUtc == createdAtUtc;

  @override
  int get hashCode => Object.hash(
    mediaUuid,
    ownerType,
    ownerId,
    tag,
    metadata,
    mediaType,
    createdAtUtc,
  );
}
