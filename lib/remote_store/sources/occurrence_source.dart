import '../../sdk/interfaces/occurrence.dart';
import '../../sdk/models/enums.dart';
import '../../sdk/models/occurrence.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [OccurrenceSource] using HTTP API.
class RemoteOccurrenceSource implements OccurrenceSource {
  RemoteOccurrenceSource(this._store);

  final RemoteStore _store;

  @override
  Future<Occurrence> getOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    final response = await _store.get(
      endpoints.occurrences.occurrence(eventId, timeStr),
    );
    return Occurrence.fromMap(response);
  }

  @override
  Future<List<Occurrence>> listOccurrences({
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
    EventType? eventType,
    Visibility? visibility,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{
      'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
      'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
      if (eventType != null) 'type': eventType.name,
      if (visibility != null) 'visibility': visibility.name,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };
    final response = await _store.getList(
      endpoints.occurrences.list,
      queryParams: queryParams,
    );
    return response
        .map((item) => Occurrence.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> rescheduleOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
    DateTime? newStartTimeUtc,
    int? newDurationMinutes,
    int? newVenueId,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    await _store.postVoid(
      endpoints.occurrences.reschedule(eventId, timeStr),
      body: {
        'version': version,
        if (newStartTimeUtc != null)
          'newStartTimeUtc': newStartTimeUtc.millisecondsSinceEpoch,
        'newDurationMinutes': ?newDurationMinutes,
        'newVenueId': ?newVenueId,
      },
    );
  }

  @override
  Future<void> cancelOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
    required String reason,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    await _store.postVoid(
      endpoints.occurrences.cancel(eventId, timeStr),
      body: {
        'version': version,
        'reason': reason,
      },
    );
  }

  @override
  Future<void> undoCancelOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    await _store.postVoid(
      endpoints.occurrences.undoCancel(eventId, timeStr),
      body: {'version': version},
    );
  }
}
