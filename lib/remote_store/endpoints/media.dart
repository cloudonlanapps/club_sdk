import 'package:meta/meta.dart';

@immutable
class MediaEndpoints {
  const MediaEndpoints();

  String get list => '/media';
  String get myFiles => '/media/myfiles';
  String get upload => '/media';
  String byId(int id) => '/media/by_id/$id';
  String download(String uuid) => '/media/by_id/$uuid/download';
  String linksByUuid(String uuid) => '/media/by_id/$uuid/links';
  String get crossOwnerLinks => '/media/links';
  String restore(int id) => '/media/by_id/$id/restore';
  String hardDelete(int id) => '/media/by_id/$id/hard';
}

/// URL builder for the per-owner media link tables (#162).
///
/// All four owners share the same path shape:
/// `/<ownerSegment>/by_id/<id>/media[/<tag>[/<mediaUuid>]]`
@immutable
class OwnerMediaEndpoints {
  const OwnerMediaEndpoints();

  String list(String ownerSegment, String ownerId) =>
      '/$ownerSegment/by_id/$ownerId/media';

  String tag(String ownerSegment, String ownerId, String tag) =>
      '/$ownerSegment/by_id/$ownerId/media/$tag';

  String one(
    String ownerSegment,
    String ownerId,
    String tag,
    String mediaUuid,
  ) => '/$ownerSegment/by_id/$ownerId/media/$tag/$mediaUuid';
}
