/// Enrolment credit for suites that are not about credit (#38).
///
/// Where the credit system is on, the server gates the enrolment itself:
/// inviting or assigning a member to a **programme** requires them to
/// hold at least one usable credit (server R36), and marking attendance
/// then spends one per occurrence. A suite that seeds a programme
/// enrolment without granting credit is refused with
/// `INSUFFICIENT_CREDIT` on a stack with the module on, and passes on one
/// with it off — which is why the whole directory could not run green on
/// both confs.
///
/// These helpers make that difference disappear. Call [seedEnrolmentCredit]
/// in `setUpAll` before the enrolments, as the admin. Where the credit
/// system is off it does nothing at all, so a suite reads the same on
/// either stack and keeps asserting exactly what it asserted before.
library;

import 'package:club_sdk_2/club_sdk_2.dart';

/// Enough credit that no suite runs a member dry part way through.
///
/// Sessions cost one credit each and nothing here marks hundreds of them;
/// the number only has to be comfortably larger than any suite's appetite,
/// because these accounts exist to get out of the way, not to be counted.
const seededCredits = 500;

/// Grants each of [members] a general account, and a general trial
/// account, usable for any programme.
///
/// A no-op unless [creditSystemOn]. General accounts pay for any
/// programme, so one grant covers every event a suite creates; the trial
/// account is separate because trial enrolments are funded only by trial
/// credit and never mix with ordinary credit in either direction.
///
/// The window opens a day back and runs a year out, so a grant is usable
/// the moment it is made whatever the hour, and outlives any fixture the
/// suites place inside the scheduling horizon.
///
/// [client] must be logged in as an admin.
Future<void> seedEnrolmentCredit(
  SecureClient client,
  List<String> members, {
  required bool creditSystemOn,
  String reason = 'test fixture',
}) async {
  if (!creditSystemOn) return;

  final validFrom = _dayFromToday(-1);
  final validUntil = _dayFromToday(365);

  for (final member in members) {
    for (final isTrial in [false, true]) {
      await client.credits.openAccount(
        membername: member,
        credits: seededCredits,
        validFromUtc: validFrom,
        validUntilUtc: validUntil,
        reason: reason,
        isTrial: isTrial,
      );
    }
  }
}

/// Reads the capabilities and seeds in one step, returning whether the
/// credit system is on so the caller can keep the answer.
Future<bool> seedEnrolmentCreditIfGated(
  SecureClient client,
  List<String> members, {
  String reason = 'test fixture',
}) async {
  final on = (await client.capabilities.getCapabilities()).creditSystem;
  await seedEnrolmentCredit(
    client,
    members,
    creditSystemOn: on,
    reason: reason,
  );
  return on;
}

DateTime _dayFromToday(int days) {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day).add(Duration(days: days));
}
