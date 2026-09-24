import 'dart:convert';

import 'package:meta/meta.dart';

/// A media item as a client needs it to paint (club_server#424, #426).
///
/// Everywhere the server publishes a media item it publishes one of these. A
/// bare uuid tells a client nothing: the download URL has no extension
/// either, so a renderer that decides between a picture, a video and a
/// document has nothing to read and gets it wrong.
///
/// Three fields, and no fourth. [mimeType] picks the renderer on its own —
/// every stored item is `image/*`, `video/*` or `application/pdf` — and
/// [filename] goes in the download URL, which the server ignores for lookup,
/// so the URL ends in a real extension.
///
/// Per-variant facts are deliberately absent. A `HEAD` on the download URL
/// answers a variant's type, its size and whether it exists, for exactly the
/// variant asked about.
@immutable
class MediaRef {
  const MediaRef({
    required this.uuid,
    required this.mimeType,
    required this.filename,
  });

  factory MediaRef.fromMap(Map<String, dynamic> map) {
    return MediaRef(
      uuid: map['uuid'] as String,
      mimeType: map['mimeType'] as String,
      filename: map['filename'] as String,
    );
  }

  factory MediaRef.fromJson(String source) =>
      MediaRef.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The media uuid. Addresses the file; says nothing about it.
  final String uuid;

  /// The `Content-Type` a download of the original will carry.
  ///
  /// Describes the artifact that is *served*, which is not always what was
  /// uploaded: a PNG uploaded without `preserveOriginal` is stored and served
  /// as WebP.
  final String mimeType;

  /// The name to put in the download URL and to save the file under.
  ///
  /// Built by the server from the upload's name, prefixed with eight
  /// characters of the uuid — two events can easily attach files with the
  /// same basename — and given the extension of what is served.
  final String filename;

  /// The coarse kind, for callers whose own vocabulary is `image` / `video`
  /// / `pdf` rather than a MIME type. Derived, never published: the server
  /// sends [mimeType] alone, and this is that answer rounded down.
  String get mediaTypeWord => isVideo
      ? 'video'
      : isPdf
      ? 'pdf'
      : 'image';

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isPdf => mimeType == 'application/pdf';

  /// Whether a still preview can exist for this item.
  ///
  /// A video has a frame and a PDF a first page; an image is its own preview.
  /// Whether the server actually rendered one is a `HEAD` away — it is not
  /// published, because a list of variant names describes the media *type*
  /// rather than the item, and said `poster` for documents that have none.
  bool get mayHavePoster => isVideo || isPdf;

  /// Whether an animated preview can exist for this item. Videos only.
  bool get mayHaveAnimated => isVideo;

  Map<String, dynamic> toMap() => {
    'uuid': uuid,
    'mimeType': mimeType,
    'filename': filename,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'MediaRef(uuid: $uuid, mimeType: $mimeType)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaRef &&
        other.uuid == uuid &&
        other.mimeType == mimeType &&
        other.filename == filename;
  }

  @override
  int get hashCode => uuid.hashCode ^ mimeType.hashCode ^ filename.hashCode;
}
