import '../models/event_marketing.dart';

/// Staff-side access to an event's extended marketing block
/// (`/events/by_id/{id}/marketing`, club_server#410, #22).
///
/// The Event Marketing module is switched per deployment; where it is off
/// every call here is a 503 `ModuleDisabledException`. Read
/// `CapabilitiesSource.getCapabilities().eventMarketing` and hide the
/// feature rather than reaching that. The public reads live on
/// `PublicSource`.
///
/// The block has a version of its own, apart from the event's
/// (club_server#13, #1): [EventMarketing.version], which every write moves
/// one on. An event nobody has written a block for is at
/// [EventMarketing.unwrittenVersion], and so is one whose block was
/// removed. Writing or removing the block leaves the event's version alone.
abstract interface class EventMarketingSource {
  /// The block, for an admin or coach, with its version and who wrote it
  /// last. 404 `EVENT_MARKETING_NOT_FOUND` when the event has none; the
  /// version to write at is then [EventMarketing.unwrittenVersion].
  Future<EventMarketing> getEventMarketing(int eventId);

  /// Replaces the whole block (`PUT`), for an admin or the event's
  /// organizer: a field left `null` on [marketing] is cleared. Returns the
  /// stored block, at its new version. Audited.
  ///
  /// [version] is the block version the caller last loaded, or
  /// [EventMarketing.unwrittenVersion] for an event with no block; the one
  /// on [marketing] is not sent. A stale one is refused with
  /// `StaleVersionException`, which carries the block's current version and
  /// who wrote it, and nothing is written.
  Future<EventMarketing> setEventMarketing(
    int eventId,
    EventMarketing marketing, {
    required int version,
  });

  /// Removes the block (`DELETE`), for an admin or the event's organizer.
  /// Audited.
  ///
  /// [version] is the block version the caller last loaded; a stale one is
  /// refused with `StaleVersionException` and the block stays.
  Future<void> clearEventMarketing(int eventId, {required int version});
}
