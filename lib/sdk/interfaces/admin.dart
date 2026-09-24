import '../models/staff_listing_row.dart';
import '../models/system_preference.dart';

/// Administrative settings held server-side rather than per deployment.
///
/// Preferences are super-admin only. The email banner logo moves here under
/// club_server#320 and #321, so this is the surface an admin UI writes to.
/// The staff-listing curation (admin) lives here too (club_server#332,
/// #24).
abstract interface class AdminSource {
  /// Lists every system preference.
  Future<List<SystemPreference>> listPreferences();

  /// Reads one preference by key.
  Future<SystemPreference> getPreference(String key);

  /// Writes one preference. [value] is opaque JSON; its shape depends on the
  /// key.
  Future<SystemPreference> setPreference(String key, Object? value);

  /// The whole staff listing: every coach who has consented to the staff
  /// page, with their curation (admin only).
  Future<List<StaffListingRow>> listStaffListing();

  /// Upserts one coach's curation. Only the fields given change; a
  /// [position] getter returning `null` clears the order. Curation never
  /// grants visibility: the coach's own consent still decides.
  Future<StaffListingRow> setStaffListing(
    String username, {
    int? Function()? position,
    bool? isGuest,
    bool? isHidden,
  });

  /// Removes a coach's curation row, leaving them public and uncurated.
  Future<void> clearStaffListing(String username);
}
