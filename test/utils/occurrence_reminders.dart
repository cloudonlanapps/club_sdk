/// Test helpers for the reminders club_server's scheduler sends for an
/// occurrence (club_server#49, #50; SDK #44, #45).
///
/// The scheduler wakes every five minutes. Each tick sends
/// `event.upcoming_reminder` to the enrolled members of every live
/// occurrence starting within the next 24 hours (and again within the next
/// hour). `attendance.pending_mark_reminder`, sent to every active admin and
/// coach for a session that ended in the last seven days with no attendance
/// recorded, is scanned on the **first** tick, five minutes after the server
/// starts, and then only hourly. No API triggers either scan, so a test
/// creates its occurrences and waits for a tick, with a bounded poll.
///
/// Each reminder's payload carries `data.eventId` and
/// `data.occurrenceTimeUtc` (milliseconds), which is how the server matches
/// the reminders of one occurrence and how these helpers find them.
library;

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// The notification type of a member's reminder of an upcoming occurrence.
const upcomingReminder = 'event.upcoming_reminder';

/// The notification type of a staff reminder to mark a finished session.
const pendingMarkReminder = 'attendance.pending_mark_reminder';

/// How often the server's scheduler wakes (`SCHEDULER_TICK_SECONDS`).
const schedulerTick = Duration(minutes: 5);

/// Longest wait for a tick that is due: one tick plus room for the scan.
const tickWait = Duration(minutes: 7);

/// Room between bootstrapping `sudo` and the server's scheduler starting,
/// plus the time the first scan takes.
const firstScanAllowance = Duration(minutes: 3);

/// How often a wait re-reads the inbox.
const pollEvery = Duration(seconds: 10);

/// The largest page the notifications list serves.
const inboxPage = 100;

/// Whether [n] is a reminder of [type] for [eventId]'s occurrence at
/// [occurrenceTimeUtc].
bool isReminderFor(
  AppNotification n,
  String type,
  int eventId,
  DateTime occurrenceTimeUtc,
) {
  if (n.type != type) return false;
  final data = n.payload['data'];
  if (data is! Map) return false;
  return data['eventId'] == eventId &&
      data['occurrenceTimeUtc'] == occurrenceTimeUtc.millisecondsSinceEpoch;
}

/// The [type] reminders in the signed-in user's inbox for [eventId]'s
/// occurrence at [occurrenceTimeUtc].
Future<List<AppNotification>> remindersFor(
  SecureClient client,
  String type,
  int eventId,
  DateTime occurrenceTimeUtc,
) async {
  final page = await client.notifications.getNotifications(limit: inboxPage);
  return page.items
      .where((n) => isReminderFor(n, type, eventId, occurrenceTimeUtc))
      .toList();
}

/// Waits until [client]'s inbox holds a [type] reminder for every
/// `(eventId, occurrenceTimeUtc)` in [occurrences], failing the test once
/// [deadline] passes with the ones still missing.
Future<void> waitForReminders(
  SecureClient client,
  String type,
  List<(int, DateTime)> occurrences, {
  required DateTime deadline,
}) async {
  var missing = occurrences;
  while (true) {
    final page = await client.notifications.getNotifications(limit: inboxPage);
    missing = [
      for (final (eventId, t) in missing)
        if (!page.items.any((n) => isReminderFor(n, type, eventId, t)))
          (eventId, t),
    ];
    if (missing.isEmpty) return;
    if (DateTime.now().toUtc().isAfter(deadline)) {
      fail('No $type by $deadline for (eventId, occurrence) $missing');
    }
    await Future<void>.delayed(pollEvery);
  }
}

/// When the stack's first pending-mark scan will have run, or `null` when
/// it is already behind us and the next one is an hour of ticks away.
///
/// The bootstrap creates `sudo` just before the server starts, so its
/// `createdAtUtc` dates the stack. [sudoClient] must be signed in as sudo.
/// Call it after creating the occurrences the scan must see.
Future<DateTime?> firstPendingMarkScanDeadline(SecureClient sudoClient) async {
  final sudo = await sudoClient.auth.getCurrentUser();
  final firstTick = sudo.createdAtUtc.toUtc().add(schedulerTick);
  if (!DateTime.now().toUtc().isBefore(firstTick)) return null;
  return firstTick.add(firstScanAllowance);
}

/// Why a test that needs the pending-mark scan cannot run on this stack.
String pendingMarkScanSkip(int issue, String testFile) =>
    "club_sdk#$issue — the pending-mark scan runs on the scheduler's first "
    'tick, 5 minutes after the server starts, and then hourly, and no API '
    'triggers it. This stack was up before the test could seed its '
    'sessions; run the file on a fresh stack: just test-one $testFile';
