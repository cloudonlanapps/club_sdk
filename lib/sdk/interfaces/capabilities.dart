import '../models/capabilities.dart';

/// Deployment capability discovery (`GET /capabilities`, any authenticated
/// user, including one still awaiting approval).
///
/// An interface like every other source on `SecureClient`, so apps can
/// override it in tests.
// ignore: one_member_abstracts
abstract interface class CapabilitiesSource {
  /// What this deployment can do. Read once after login; the answer is
  /// deploy configuration and does not change at runtime.
  Future<Capabilities> getCapabilities();
}
