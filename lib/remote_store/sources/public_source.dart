import '../../sdk/interfaces/public.dart';
import '../../sdk/models/enums.dart';
import '../../sdk/models/event_marketing.dart';
import '../../sdk/models/inquiry_kind.dart';
import '../../sdk/models/pagination.dart';
import '../../sdk/models/public_club_info.dart';
import '../../sdk/models/public_event.dart';
import '../../sdk/models/public_profile.dart';
import '../../sdk/models/public_venue.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [PublicSource] using the unauthenticated
/// `/public` HTTP API.
class RemotePublicSource implements PublicSource {
  RemotePublicSource(this._store);

  final RemoteStore _store;

  @override
  Future<List<PublicProfile>> listPublicStaff({
    bool includeGuests = false,
  }) async {
    final response = await _store.getList(
      endpoints.public.staff,
      queryParams: {if (includeGuests) 'include_guests': 'true'},
    );
    return response
        .map((e) => PublicProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PublicProfile> getPublicProfile(String publicId) async {
    final response = await _store.get(endpoints.public.profileById(publicId));
    return PublicProfile.fromMap(response);
  }

  @override
  Future<PaginatedList<PublicEvent>> listPublicEvents({
    EventType? type,
    DateTime? from,
    DateTime? to,
    bool? featured,
    String? venueId,
    int? offset,
    int? limit,
  }) async {
    final response = await _store.get(
      endpoints.public.events,
      queryParams: {
        if (type != null) 'type': type.name,
        if (from != null) 'from': from.millisecondsSinceEpoch.toString(),
        if (to != null) 'to': to.millisecondsSinceEpoch.toString(),
        if (featured != null) 'featured': featured.toString(),
        'venueId': ?venueId,
        if (offset != null) 'offset': offset.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, PublicEvent.fromMap);
  }

  @override
  Future<PublicEvent> getPublicEvent(String publicId) async {
    final response = await _store.get(endpoints.public.event(publicId));
    return PublicEvent.fromMap(response);
  }

  @override
  Future<EventMarketing> getPublicEventMarketing(String publicId) async {
    final response = await _store.get(
      endpoints.public.eventMarketing(publicId),
    );
    return EventMarketing.fromMap(response);
  }

  @override
  Future<Map<String, EventMarketing>> listPublicEventMarketing(
    List<String> publicIds,
  ) async {
    final response = await _store.getList(
      endpoints.public.eventsMarketing,
      queryParams: {'ids': publicIds.join(',')},
    );
    return {
      for (final item in response.cast<Map<String, dynamic>>())
        item['publicId'] as String: EventMarketing.fromMap(item),
    };
  }

  @override
  Future<List<PublicVenue>> listPublicVenues() async {
    final response = await _store.getList(endpoints.public.venues);
    return response
        .map((e) => PublicVenue.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PublicVenue> getPublicVenue(String publicId) async {
    final response = await _store.get(endpoints.public.venue(publicId));
    return PublicVenue.fromMap(response);
  }

  @override
  Future<PublicClubInfo> getPublicClubInfo() async {
    final response = await _store.get(endpoints.clubInfo.publicClubInfo);
    return PublicClubInfo.fromMap(response);
  }

  @override
  Future<String> getInquiryFormToken() async {
    final response = await _store.get(endpoints.inquiries.formToken);
    return response['token'] as String;
  }

  @override
  Future<void> submitInquiry({
    required InquiryKind kind,
    required String name,
    required String email,
    required String message,
    required String token,
    String? phone,
    Map<String, dynamic>? extra,
    String? website,
  }) {
    return _store.postVoid(
      endpoints.inquiries.submit,
      body: {
        'kind': kind.wireName,
        'name': name,
        'email': email,
        'message': message,
        'token': token,
        'phone': ?phone,
        'extra': ?extra,
        'website': ?website,
      },
    );
  }
}
