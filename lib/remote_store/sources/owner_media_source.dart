import '../../sdk/interfaces/owner_media.dart';
import '../../sdk/models/media_link.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Shared HTTP implementation used by the four owner-media facades.
///
/// Builds URLs from an `ownerSegment` (`users` / `events` / `groups` /
/// `venues`) and forwards CRUD operations through `RemoteStore`. The
/// public facades are thin adapters that supply typed owner IDs and the
/// owner-segment string.
class OwnerMediaClient {
  OwnerMediaClient(this._store, this._ownerSegment);

  final RemoteStore _store;
  final String _ownerSegment;

  Future<Map<String, List<MediaLink>>> listGrouped(String ownerId) async {
    final response = await _store.get(
      endpoints.ownerMedia.list(_ownerSegment, ownerId),
    );
    return response.map((tag, value) {
      final items = (value as List)
          .whereType<Map<String, dynamic>>()
          .map(MediaLink.fromMap)
          .toList(growable: false);
      return MapEntry(tag, items);
    });
  }

  Future<List<MediaLink>> listByTag(String ownerId, String tag) async {
    final response = await _store.getList(
      endpoints.ownerMedia.tag(_ownerSegment, ownerId, tag),
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(MediaLink.fromMap)
        .toList(growable: false);
  }

  Future<MediaLink> get(String ownerId, String tag, String mediaUuid) async {
    final response = await _store.get(
      endpoints.ownerMedia.one(_ownerSegment, ownerId, tag, mediaUuid),
    );
    return MediaLink.fromMap(response);
  }

  Future<MediaLink> attach(
    String ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) async {
    final response = await _store.post(
      endpoints.ownerMedia.list(_ownerSegment, ownerId),
      body: {
        'tag': tag,
        'mediaUuid': mediaUuid,
        'metadata': ?metadata,
      },
    );
    return MediaLink.fromMap(response);
  }

  Future<MediaLink> updateMetadata(
    String ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) async {
    final response = await _store.patch(
      endpoints.ownerMedia.one(_ownerSegment, ownerId, tag, mediaUuid),
      body: {'metadata': metadata},
    );
    return MediaLink.fromMap(response);
  }

  Future<void> detach(String ownerId, String tag, String mediaUuid) async {
    await _store.delete(
      endpoints.ownerMedia.one(_ownerSegment, ownerId, tag, mediaUuid),
    );
  }

  Future<void> detachTag(String ownerId, String tag) async {
    await _store.delete(
      endpoints.ownerMedia.tag(_ownerSegment, ownerId, tag),
    );
  }
}

class RemoteUserMediaSource implements UserMediaSource {
  RemoteUserMediaSource(RemoteStore store)
    : _client = OwnerMediaClient(store, 'users');

  final OwnerMediaClient _client;

  @override
  Future<Map<String, List<MediaLink>>> listGrouped(String ownerId) =>
      _client.listGrouped(ownerId);

  @override
  Future<List<MediaLink>> listByTag(String ownerId, String tag) =>
      _client.listByTag(ownerId, tag);

  @override
  Future<MediaLink> get(String ownerId, String tag, String mediaUuid) =>
      _client.get(ownerId, tag, mediaUuid);

  @override
  Future<MediaLink> attach(
    String ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _client.attach(
    ownerId,
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  @override
  Future<MediaLink> updateMetadata(
    String ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _client.updateMetadata(
    ownerId,
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  @override
  Future<void> detach(String ownerId, String tag, String mediaUuid) =>
      _client.detach(ownerId, tag, mediaUuid);

  @override
  Future<void> detachTag(String ownerId, String tag) =>
      _client.detachTag(ownerId, tag);
}

/// Internal helper for the int-owner facades (event / group / venue): they
/// all delegate to the same shared client with the owner id stringified.
class IntOwnerMediaAdapter {
  IntOwnerMediaAdapter(this._client);

  final OwnerMediaClient _client;

  Future<Map<String, List<MediaLink>>> listGrouped(int ownerId) =>
      _client.listGrouped(ownerId.toString());

  Future<List<MediaLink>> listByTag(int ownerId, String tag) =>
      _client.listByTag(ownerId.toString(), tag);

  Future<MediaLink> get(int ownerId, String tag, String mediaUuid) =>
      _client.get(ownerId.toString(), tag, mediaUuid);

  Future<MediaLink> attach(
    int ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _client.attach(
    ownerId.toString(),
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  Future<MediaLink> updateMetadata(
    int ownerId, {
    required String tag,
    required String mediaUuid,
    String? metadata,
  }) => _client.updateMetadata(
    ownerId.toString(),
    tag: tag,
    mediaUuid: mediaUuid,
    metadata: metadata,
  );

  Future<void> detach(int ownerId, String tag, String mediaUuid) =>
      _client.detach(ownerId.toString(), tag, mediaUuid);

  Future<void> detachTag(int ownerId, String tag) =>
      _client.detachTag(ownerId.toString(), tag);
}

class RemoteEventMediaSource implements EventMediaSource {
  RemoteEventMediaSource(RemoteStore store)
    : _adapter = IntOwnerMediaAdapter(OwnerMediaClient(store, 'events'));

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

class RemoteGroupMediaSource implements GroupMediaSource {
  RemoteGroupMediaSource(RemoteStore store)
    : _adapter = IntOwnerMediaAdapter(OwnerMediaClient(store, 'groups'));

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

class RemoteVenueMediaSource implements VenueMediaSource {
  RemoteVenueMediaSource(RemoteStore store)
    : _adapter = IntOwnerMediaAdapter(OwnerMediaClient(store, 'venues'));

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
