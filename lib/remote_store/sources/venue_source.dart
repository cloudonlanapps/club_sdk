import '../../sdk/interfaces/venue.dart';
import '../../sdk/models/pagination.dart';
import '../../sdk/models/venue.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [VenueSource] using HTTP API.
class RemoteVenueSource implements VenueSource {
  RemoteVenueSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<Venue>> getVenues({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.venues.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(
      response,
      Venue.fromMap,
    );
  }

  @override
  Future<Venue> getVenue(int id) async {
    final response = await _store.get(endpoints.venues.venue(id));
    return Venue.fromMap(response);
  }

  @override
  Future<Venue> createVenue({
    required String name,
    bool isDefault = false,
    String? address,
    String? description,
    String? mapUri,
    bool isFeatured = false,
  }) async {
    final response = await _store.post(
      endpoints.venues.list,
      body: {
        'name': name,
        'isDefault': isDefault,
        'address': ?address,
        'description': ?description,
        'mapUri': ?mapUri,
        'isFeatured': isFeatured,
      },
    );
    return Venue.fromMap(response);
  }

  @override
  Future<Venue> updateVenue(
    int id, {
    String? name,
    bool? isDefault,
    String? Function()? address,
    String? Function()? description,
    String? Function()? mapUri,
    bool? isFeatured,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'isDefault': ?isDefault,
      'isFeatured': ?isFeatured,
    };

    // Handle ValueGetter pattern for nullable fields
    if (address != null) {
      body['address'] = address();
    }
    if (description != null) {
      body['description'] = description();
    }
    if (mapUri != null) {
      body['mapUri'] = mapUri();
    }

    final response = await _store.patch(endpoints.venues.venue(id), body: body);
    return Venue.fromMap(response);
  }

  @override
  Future<PaginatedList<Venue>> getDeletedVenues({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.venues.deleted,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Venue.fromMap);
  }

  @override
  Future<Venue> deleteVenue(int id) async {
    final response = await _store.delete(endpoints.venues.venue(id));
    return Venue.fromMap(response!);
  }

  @override
  Future<Venue> restoreVenue(int id) async {
    final response = await _store.post(endpoints.venues.restore(id));
    return Venue.fromMap(response);
  }

  @override
  Future<void> hardDeleteVenue(int id) async {
    await _store.delete(endpoints.venues.hardDelete(id));
  }
}
