import 'package:meta/meta.dart';

/// What one variant of a media item is, as a `HEAD` on its download URL
/// answers it (club_server#426).
///
/// Per-variant facts are not embedded in any projection — `MediaRef` carries
/// only the original's type — so a client asks about the variant it wants.
@immutable
class MediaVariantInfo {
  const MediaVariantInfo({required this.contentType, this.contentLength});

  /// The `Content-Type` a download of this variant carries.
  final String contentType;

  /// The variant's size in bytes, or null when the server did not say.
  final int? contentLength;

  MediaVariantInfo copyWith({
    String? contentType,
    int? Function()? contentLength,
  }) {
    return MediaVariantInfo(
      contentType: contentType ?? this.contentType,
      contentLength: contentLength != null
          ? contentLength()
          : this.contentLength,
    );
  }

  @override
  String toString() =>
      'MediaVariantInfo(contentType: $contentType, '
      'contentLength: $contentLength)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaVariantInfo &&
        other.contentType == contentType &&
        other.contentLength == contentLength;
  }

  @override
  int get hashCode => contentType.hashCode ^ contentLength.hashCode;
}
