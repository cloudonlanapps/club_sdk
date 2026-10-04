import '../models/event_marketing.dart';

/// Staff-side access to an event's extended marketing block
/// (`/events/by_id/{id}/marketing`, club_server#410, #22).
///
/// The Event Marketing module is switched per deployment; where it is off
/// every call here is a 503 `ModuleDisabledException`. Read
/// `CapabilitiesSource.getCapabilities().eventMarketing` and hide the
/// feature rather than reaching that. The public reads live on
/// `PublicSource`.
abstract interface class EventMarketingSource {
  /// The block, for an admin or coach. 404 `EVENT_MARKETING_NOT_FOUND`
  /// when the event has none.
  Future<EventMarketing> getEventMarketing(int eventId);

  /// Replaces the whole block (`PUT`), for an admin or the event's
  /// organizer: a field left `null` on [marketing] is cleared. Returns the
  /// stored block. Audited.
  Future<EventMarketing> setEventMarketing(
    int eventId,
    EventMarketing marketing,
  );

  /// Removes the block (`DELETE`), for an admin or the event's organizer.
  /// 404 `EVENT_MARKETING_NOT_FOUND` when there is none. Audited.
  Future<void> clearEventMarketing(int eventId);
}
