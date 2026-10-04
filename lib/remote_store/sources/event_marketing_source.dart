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
    EventMarketing marketing,
  ) async {
    final response = await _store.put(
      endpoints.eventMarketing.marketing(eventId),
      body: marketing.toMap(),
    );
    return EventMarketing.fromMap(response);
  }

  @override
  Future<void> clearEventMarketing(int eventId) async {
    await _store.delete(endpoints.eventMarketing.marketing(eventId));
  }
}
