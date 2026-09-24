import '../models/media_ref.dart';

/// Parsed parts of a v2 media download URL.
///
/// `uuid` is the media uuid embedded in the URL path. `variant` is the
/// `variant` query parameter; defaults to `original` when absent (matching
/// the server's default).
typedef MediaDownloadUrlParts = ({String uuid, String variant});

/// Parse a v2 media download URL into its (uuid, variant) parts.
///
/// Returns `null` for URLs that don't match the v2 shape
/// (`.../media/by_id/<uuid>/download[?variant=<v>]`). Legacy
/// `/uploaded/by_id/...` URLs are not recognised — they are deprecating.
MediaDownloadUrlParts? mediaDownloadUrlParts(String url) {
  Uri parsed;
  try {
    parsed = Uri.parse(url);
  } on FormatException {
    return null;
  }
  final segments = parsed.pathSegments;
  // Match the `media/by_id/<uuid>/download` suffix; ignore any leading path
  // segments (e.g. `/v1`) so the helper works whether or not the API base URL
  // pins a version prefix, and any trailing one, which is the decorative
  // filename the download route accepts and ignores (club_server#424).
  final download = segments.lastIndexOf('download');
  if (download < 3) return null;
  if (segments[download - 2] != 'by_id') return null;
  if (segments[download - 3] != 'media') return null;
  if (segments.length > download + 2) return null;
  final uuid = segments[download - 1];
  if (uuid.isEmpty) return null;
  final variant = parsed.queryParameters['variant'] ?? 'original';
  return (uuid: uuid, variant: variant);
}

/// The download URL for [media], for a given variant (club_server#424).
///
/// [apiBaseUrl] is the API root (with or without a trailing slash). The
/// `original` variant gets the filename-bearing path — the server ignores the
/// name for the lookup, so it is decorative, but it makes the URL end in a
/// real extension, which is what an extension-sniffing renderer reads and
/// what a browser saves the file under. Other variants are addressed by query
/// parameter and are always images.
///
/// One implementation, because every consumer was building this by hand and
/// the shape is the server's, not theirs.
String mediaDownloadUrl(
  String apiBaseUrl,
  MediaRef media, {
  String variant = 'original',
}) {
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  final path = '$base/media/by_id/${media.uuid}/download';
  if (variant == 'original') {
    return '$path/${Uri.encodeComponent(media.filename)}';
  }
  return '$path?variant=$variant';
}

/// Where [media]'s still preview would be, or `null` for an image.
///
/// A video's frame and a PDF's first page live at `?variant=poster`; an image
/// is its own preview, so `null` beats a URL that cannot exist.
///
/// Whether the server actually rendered one is not published, and this does
/// not pretend to know: a `preserveOriginal` document has no page image, and
/// the URL 404s. Callers that must know before rendering can `HEAD` it; the
/// rest can let the image load fail.
String? mediaPosterUrl(String apiBaseUrl, MediaRef media) => media.mayHavePoster
    ? mediaDownloadUrl(apiBaseUrl, media, variant: 'poster')
    : null;

/// Where [media]'s animated preview would be, or `null` when it is not a
/// video. Same caveat as [mediaPosterUrl].
String? mediaAnimatedUrl(String apiBaseUrl, MediaRef media) =>
    media.mayHaveAnimated
    ? mediaDownloadUrl(apiBaseUrl, media, variant: 'animated')
    : null;
