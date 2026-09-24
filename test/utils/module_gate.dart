/// Gating helper for the optional-module suites (#14, #15, #22).
///
/// `credit_system_enabled`, `evaluations_enabled` and
/// `event_marketing_enabled` are deployment settings, so the same suite
/// meets both answers: `just sdk-test` runs against a stack with the
/// modules off and `just sdk-test-modules` against one with them on. The
/// routes stay registered either way — off, they answer 503 — so a suite
/// asserts the 503 on the off stack and the behaviour on the on stack,
/// and never silently passes because it ran against the wrong conf.
library;

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Which optional modules this stack was started with.
Future<Capabilities> stackCapabilities(SecureClient client) =>
    client.capabilities.getCapabilities();

/// Marks the running test skipped and returns true when [enabled] is
/// false, so a body can open with:
///
/// ```dart
/// if (skipUnless(enabled: creditsOn, module: 'credit system')) return;
/// ```
///
/// The run then reports the case as skipped against this conf rather than
/// as a pass that asserted nothing.
bool skipUnless({required bool enabled, required String module}) {
  if (enabled) return false;
  markTestSkipped('$module is off on this stack');
  return true;
}

/// Matches the 503 every route of a disabled module answers with.
Matcher throwsModuleDisabled(String errorCode) => throwsA(
  isA<ModuleDisabledException>()
      .having((e) => e.statusCode, 'status', 503)
      .having((e) => e.code, 'code', errorCode),
);
