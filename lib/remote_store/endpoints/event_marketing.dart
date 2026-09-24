import 'package:meta/meta.dart';

@immutable
class EventMarketingEndpoints {
  const EventMarketingEndpoints();

  /// `GET` / `PUT` / `DELETE` an event's extended marketing block.
  String marketing(int eventId) => '/events/by_id/$eventId/marketing';
}
