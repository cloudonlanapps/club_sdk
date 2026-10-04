import 'dart:convert';

import '../../sdk/exceptions/exceptions.dart';
import '../../sdk/interfaces/media.dart';
import '../../sdk/models/media.dart';
import '../../sdk/models/media_link.dart';
import '../../sdk/models/media_variant_info.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [MediaSource] using HTTP API (v2 media, #161).
class RemoteMediaSource implements MediaSource {
  RemoteMediaSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<Media>> list({
    int offset = 0,
    int limit = 20,
    String? mediaType,
    String? conversionStatus,
    bool includeDeleted = false,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      'includeDeleted': includeDeleted.toString(),
      'mediaType': ?mediaType,
      'conversionStatus': ?conversionStatus,
    };
    final response = await _store.get(
      endpoints.media.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Media.fromMap);
  }

  @override
  Future<PaginatedList<Media>> listMyFiles({
    int offset = 0,
    int limit = 20,
    String? mediaType,
    String? conversionStatus,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      'mediaType': ?mediaType,
      'conversionStatus': ?conversionStatus,
    };
    final response = await _store.get(
      endpoints.media.myFiles,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Media.fromMap);
  }

  @override
  Future<Media> upload({
    required List<int> fileBytes,
    required String filename,
    String? contentType,
    bool preserveOriginal = false,
    double? duration,
    double? start,
    List<String>? accessRoles,
    bool encrypt = false,
  }) async {
    final fields = <String, String>{
      'preserveOriginal': preserveOriginal.toString(),
      'encrypt': encrypt.toString(),
      if (duration != null) 'duration': duration.toString(),
      if (start != null) 'start': start.toString(),
      if (accessRoles != null) 'accessRoles': jsonEncode(accessRoles),
    };

    final response = await _store.uploadMultipart(
      endpoints.media.upload,
      fileBytes: fileBytes,
      filename: filename,
      contentType: contentType,
      fields: fields,
    );
    return Media.fromMap(response);
  }

  @override
  Future<Media> getById(int id) async {
    final response = await _store.get(endpoints.media.byId(id));
    return Media.fromMap(response);
  }

  @override
  Future<Media> patch(int id, {required List<String> accessRoles}) async {
    final response = await _store.patch(
      endpoints.media.byId(id),
      body: {'accessRoles': accessRoles},
    );
    return Media.fromMap(response);
  }

  @override
  Future<List<int>> download(
    String uuid, {
    String variant = 'original',
    String? filename,
  }) async {
    return _store.downloadBytes(
      filename == null
          ? endpoints.media.download(uuid)
          : endpoints.media.downloadNamed(uuid, filename),
      queryParams: {'variant': variant},
    );
  }

  @override
  Future<MediaVariantInfo?> probeVariant(
    String uuid, {
    String variant = 'original',
  }) async {
    final Map<String, String> headers;
    try {
      headers = await _store.head(
        endpoints.media.download(uuid),
        queryParams: {'variant': variant},
      );
    } on ServerException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    return MediaVariantInfo(
      contentType: headers['content-type'] ?? 'application/octet-stream',
      contentLength: int.tryParse(headers['content-length'] ?? ''),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getLinksRaw(String uuid) async {
    final response = await _store.getList(endpoints.media.linksByUuid(uuid));
    return response.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  @override
  Future<List<MediaLinkReverseEntry>> getLinks(String uuid) async {
    final raw = await getLinksRaw(uuid);
    return raw.map(MediaLinkReverseEntry.fromMap).toList(growable: false);
  }

  @override
  Future<PaginatedList<MediaLinkCrossEntry>> searchLinks({
    MediaLinkOwnerType? ownerType,
    String? tag,
    String? mediaType,
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      if (ownerType != null) 'ownerType': ownerType.wire,
      'tag': ?tag,
      'mediaType': ?mediaType,
    };
    final response = await _store.get(
      endpoints.media.crossOwnerLinks,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, MediaLinkCrossEntry.fromMap);
  }

  @override
  Future<void> softDelete(int id) async {
    await _store.delete(endpoints.media.byId(id));
  }

  @override
  Future<Media> restore(int id) async {
    final response = await _store.post(endpoints.media.restore(id));
    return Media.fromMap(response);
  }

  @override
  Future<void> hardDelete(int id) async {
    await _store.delete(endpoints.media.hardDelete(id));
  }
}
