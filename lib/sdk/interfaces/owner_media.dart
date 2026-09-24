import '../models/media_link.dart';

/// Common shape for per-owner media link operations.
///
/// The five owner-specific facades — [UserMediaSource], [EventMediaSource],
/// [GroupMediaSource], [VenueMediaSource], [EvaluationMediaSource] — all
/// expose the same CRUD shape
/// (only the owner-ID type varies). This interface captures the common
/// surface; concrete facades extend it with typed owner-ID method names.
abstract interface class OwnerMediaSource<OwnerId> {
  /// Tag-grouped list of all media linked to [ownerId].
  ///
  /// Returns a map keyed by tag, with the link list under each tag sorted
  /// by `createdAtUtc`.
  Future<Map<String, List<MediaLink>>> listGrouped(OwnerId ownerId);

  /// Flat list of media linked to [ownerId] under [tag].
  Future<List<MediaLink>> listByTag(OwnerId ownerId, String tag);

  /// Fetch a single link by [tag] and [mediaUuid].
  Future<MediaLink> get(OwnerId ownerId, String tag, String mediaUuid);

  /// Attach [mediaUuid] to [ownerId] under [tag]. Returns the created link.
  Future<MediaLink> attach(
    OwnerId ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  });

  /// Update the [metadata] on an existing link. Tag and mediaUuid are
  /// part of the link's identity — to change them, DELETE + POST.
  Future<MediaLink> updateMetadata(
    OwnerId ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  });

  /// Detach a single link.
  Future<void> detach(OwnerId ownerId, String tag, String mediaUuid);

  /// Detach every link under [tag] for [ownerId].
  Future<void> detachTag(OwnerId ownerId, String tag);
}

/// Per-user media. Owner ID is the username (string).
abstract interface class UserMediaSource implements OwnerMediaSource<String> {}

/// Per-event media. Owner ID is the event id (int).
abstract interface class EventMediaSource implements OwnerMediaSource<int> {}

/// Per-group media. Owner ID is the group id (int).
abstract interface class GroupMediaSource implements OwnerMediaSource<int> {}

/// Per-venue media. Owner ID is the venue id (int).
abstract interface class VenueMediaSource implements OwnerMediaSource<int> {}

/// Per-evaluation media (`/evaluations/by_id/{id}/media`, R55–R56c).
/// Owner ID is the evaluation id (int). Links are private to staff unless
/// their tag begins `shared_`, which the subject sees once the evaluation
/// is published (`MyEvaluationsSource.listMyEvaluationMedia`).
abstract interface class EvaluationMediaSource
    implements OwnerMediaSource<int> {}
