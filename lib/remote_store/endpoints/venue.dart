import 'package:meta/meta.dart';

@immutable
class VenueEndpoints {
  const VenueEndpoints();

  String get list => '/venues';
  String get deleted => '/venues/deleted';
  String venue(int id) => '/venues/by_id/$id';
  String restore(int id) => '/venues/by_id/$id/restore';
  String hardDelete(int id) => '/venues/by_id/$id/hard';
}
