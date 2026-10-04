import '../models/capabilities.dart';

/// Deployment capability discovery (`GET /capabilities`). The server answers
/// anyone, before login too, so a signup page can read it (club_server#443).
///
/// An interface like every other source on `SecureClient`, so apps can
/// override it in tests.
// ignore: one_member_abstracts
abstract interface class CapabilitiesSource {
  /// What this deployment can do. Needs no login: a client that has not
  /// authenticated gets the same answer. It is deploy configuration and
  /// does not change at runtime, so read it once.
  Future<Capabilities> getCapabilities();
}
