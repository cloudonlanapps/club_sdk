/// Server-side limits for per-owner media link tables (#162).
///
/// These mirror the server constants (`MEDIA_MAX_LINKS_PER_OWNER_TAG`,
/// `MEDIA_MAX_TAGS_PER_OWNER`) and are exposed for client-side UX —
/// the server is authoritative.
abstract final class MediaLinkLimits {
  /// Maximum links allowed under a single (owner, tag) pair.
  static const int maxLinksPerOwnerTag = 100;

  /// Maximum distinct tags allowed per owner.
  static const int maxTagsPerOwner = 50;
}
