import '../../sdk/interfaces/owner_media.dart';
import '../../sdk/models/media_link.dart';
import '../remote_store.dart';
import 'owner_media_source.dart';

/// The fifth owner-media facade: links under
/// `/evaluations/by_id/{id}/media` (R55). Same shape as the event / group /
/// venue facades, delegating to the shared [OwnerMediaClient].
class RemoteEvaluationMediaSource implements EvaluationMediaSource {
  RemoteEvaluationMediaSource(RemoteStore store)
    : _adapter = IntOwnerMediaAdapter(OwnerMediaClient(store, 'evaluations'));

  final IntOwnerMediaAdapter _adapter;

  @override
  Future<Map<String, List<MediaLink>>> listGrouped(int ownerId) =>
      _adapter.listGrouped(ownerId);

  @override
  Future<List<MediaLink>> listByTag(int ownerId, String tag) =>
      _adapter.listByTag(ownerId, tag);

  @override
  Future<MediaLink> get(int ownerId, String tag, String mediaUuid) =>
      _adapter.get(ownerId, tag, mediaUuid);

  @override
  Future<MediaLink> attach(
    int ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _adapter.attach(
    ownerId,
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  @override
  Future<MediaLink> updateMetadata(
    int ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _adapter.updateMetadata(
    ownerId,
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  @override
  Future<void> detach(int ownerId, String tag, String mediaUuid) =>
      _adapter.detach(ownerId, tag, mediaUuid);

  @override
  Future<void> detachTag(int ownerId, String tag) =>
      _adapter.detachTag(ownerId, tag);
}
