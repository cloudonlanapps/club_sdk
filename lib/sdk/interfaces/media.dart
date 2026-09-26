import '../models/media.dart';
import '../models/media_link.dart';
import '../models/media_variant_info.dart';
import '../models/pagination.dart';

/// Interface for v2 media operations.
///
/// Wraps the server's `/v1/media` subsystem.
abstract interface class MediaSource {
  /// List media records (admin/coach only). Supports filtering by
  /// [mediaType] (`image`, `video`, `pdf`) and [conversionStatus].
  ///
  /// When [includeDeleted] is true, soft-deleted records are included.
  Future<PaginatedList<Media>> list({
    int offset,
    int limit,
    String? mediaType,
    String? conversionStatus,
    bool includeDeleted,
  });

  /// List media uploaded by the caller. Available to any authenticated user.
  Future<PaginatedList<Media>> listMyFiles({
    int offset,
    int limit,
    String? mediaType,
    String? conversionStatus,
  });

  /// Upload a media file. Returns the created [Media] record.
  ///
  /// For images/pdf the server responds with 201 (synchronous). For video
  /// the server responds with 202 (async conversion queued).
  ///
  /// - [accessRoles] is a list like `['public']`, `['self']`, `['admin']`,
  ///   `['admin', 'coach']`, etc. When omitted the server defaults to
  ///   `['public']`.
  /// - [encrypt] applies to images / pdf only; videos refuse encryption.
  Future<Media> upload({
    required List<int> fileBytes,
    required String filename,
    String? contentType,
    bool preserveOriginal,
    double? duration,
    double? start,
    List<String>? accessRoles,
    bool encrypt,
  });

  /// Get media metadata by ID. Returns 404 for non-owners that are not
  /// admin/coach.
  Future<Media> getById(int id);

  /// Update mutable fields on a media record. Currently only [accessRoles]
  /// is editable.
  Future<Media> patch(int id, {required List<String> accessRoles});

  /// Download a media artifact by UUID.
  ///
  /// Variants depend on media type:
  /// - image: `original`
  /// - video: `original`, `poster`, `animated`
  /// - pdf:   `original`, `poster`
  ///
  /// Endpoint is auth-optional: public media downloads without a token;
  /// non-public media require an authenticated client.
  ///
  /// [filename] (`MediaRef.filename`) is appended to the URL, which the
  /// server ignores for the lookup (club_server#424, #426).
  Future<List<int>> download(
    String uuid, {
    String variant,
    String? filename,
  });

  /// What [variant] of a media item is — its type and size — asked with a
  /// `HEAD` on its download URL, without fetching it (club_server#426).
  ///
  /// Returns null when the item has no such variant (404), e.g. the poster
  /// of a PDF uploaded with `preserveOriginal`. Other failures throw: 400
  /// `INVALID_VARIANT` for a variant its media type never has, 409 while the
  /// file is still converting. A HEAD answer has no body, so those errors
  /// carry their status and no code.
  Future<MediaVariantInfo?> probeVariant(String uuid, {String variant});

  /// Reverse lookup: every link row referencing this media.
  ///
  /// Returns the raw payload (a `List<Map<String, dynamic>>`) for callers
  /// that want to avoid the typed model — most callers should prefer
  /// [getLinks].
  Future<List<Map<String, dynamic>>> getLinksRaw(String uuid);

  /// Reverse lookup: every link row referencing this media, typed.
  Future<List<MediaLinkReverseEntry>> getLinks(String uuid);

  /// Cross-owner search across all link tables. Admin/coach only.
  ///
  /// Use [ownerType] to restrict to one owner, [tag] to restrict to one
  /// tag, [mediaType] to restrict to one media type, or any combination.
  /// Evaluation media appear in an unfiltered search, but the server does
  /// not accept [MediaLinkOwnerType.evaluation] as the filter (422
  /// `INVALID_OWNER_TYPE`).
  Future<PaginatedList<MediaLinkCrossEntry>> searchLinks({
    MediaLinkOwnerType? ownerType,
    String? tag,
    String? mediaType,
    int offset,
    int limit,
  });

  /// Soft-delete a media record. Owner or admin/coach. Files on disk are
  /// preserved.
  ///
  /// Returns a 409 `MEDIA_IN_USE` `ServerException` (with `details.links`
  /// populated) if any owner currently links to this media.
  Future<void> softDelete(int id);

  /// Restore a soft-deleted media record. Owner or admin/coach.
  Future<Media> restore(int id);

  /// Permanently delete a soft-deleted media record. Super admin only.
  ///
  /// Returns a 409 `MEDIA_NOT_DELETED` `ServerException` if the record has
  /// not been soft-deleted first.
  Future<void> hardDelete(int id);
}
