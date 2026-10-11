import '../../sdk/interfaces/event_marketing.dart';
import '../../sdk/models/event_marketing.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [EventMarketingSource] using HTTP API.
class RemoteEventMarketingSource implements EventMarketingSource {
  RemoteEventMarketingSource(this._store);

  final RemoteStore _store;

  @override
  Future<EventMarketing> getEventMarketing(int eventId) async {
    final response = await _store.get(
      endpoints.eventMarketing.marketing(eventId),
    );
    return EventMarketing.fromMap(response);
  }

  @override
  Future<EventMarketing> setEventMarketing(
    int eventId,
    EventMarketing marketing, {
    required int version,
  }) async {
    final response = await _store.put(
      endpoints.eventMarketing.marketing(eventId),
      // The body is the fields and the version: the server refuses any
      // other key, so what a read added beside them stays behind.
      body: {
        ...marketing.toMap()
          ..remove(EventMarketing.updatedAtKey)
          ..remove(EventMarketing.updatedByKey),
        EventMarketing.versionKey: version,
      },
    );
    return EventMarketing.fromMap(response);
  }

  @override
  Future<void> clearEventMarketing(int eventId, {required int version}) async {
    await _store.delete(
      endpoints.eventMarketing.marketing(eventId),
      queryParams: {EventMarketing.versionKey: '$version'},
    );
  }
}
