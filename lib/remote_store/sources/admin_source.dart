import '../../sdk/interfaces/admin.dart';
import '../../sdk/models/staff_listing_row.dart';
import '../../sdk/models/system_preference.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [AdminSource] using the HTTP API.
class RemoteAdminSource implements AdminSource {
  RemoteAdminSource(this._store);

  final RemoteStore _store;

  @override
  Future<List<SystemPreference>> listPreferences() async {
    final response = await _store.get(endpoints.admin.preferences);
    final items = response['items'];
    if (items is! List) return const <SystemPreference>[];
    return items
        .map((e) => SystemPreference.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<SystemPreference> getPreference(String key) async {
    final response = await _store.get(endpoints.admin.preference(key));
    return SystemPreference.fromMap(response);
  }

  @override
  Future<SystemPreference> setPreference(String key, Object? value) async {
    final response = await _store.patch(
      endpoints.admin.preference(key),
      body: {'value': value},
    );
    return SystemPreference.fromMap(response);
  }

  @override
  Future<List<StaffListingRow>> listStaffListing() async {
    final response = await _store.getList(endpoints.admin.staffListing);
    return response
        .map((e) => StaffListingRow.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<StaffListingRow> setStaffListing(
    String username, {
    int? Function()? position,
    bool? isGuest,
    bool? isHidden,
  }) async {
    final response = await _store.put(
      endpoints.admin.staffListingRow(username),
      body: {
        if (position != null) 'position': position(),
        'isGuest': ?isGuest,
        'isHidden': ?isHidden,
      },
    );
    return StaffListingRow.fromMap(response);
  }

  @override
  Future<void> clearStaffListing(String username) async {
    await _store.delete(endpoints.admin.staffListingRow(username));
  }
}
