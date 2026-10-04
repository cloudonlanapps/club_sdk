import 'package:meta/meta.dart';

@immutable
class PublicEndpoints {
  const PublicEndpoints();

  String get staff => '/public/staff';
  String profileById(String publicId) => '/public/profile/by_id/$publicId';

  String get events => '/public/events';

  /// The batch marketing read; declared before the per-event path on the
  /// server so `marketing` is never taken for a public id.
  String get eventsMarketing => '/public/events/marketing';
  String event(String publicId) => '/public/events/$publicId';
  String eventMarketing(String publicId) =>
      '/public/events/$publicId/marketing';

  String get venues => '/public/venues';
  String venue(String publicId) => '/public/venues/$publicId';
}
