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

/// How far ahead [pendingMarkSession] starts its session: room to create
/// the events and assign the member before it starts.
const sessionLead = Duration(seconds: 30);

/// How long a [pendingMarkSession] lasts.
const sessionLength = Duration(minutes: 1);

/// Room left between a [pendingMarkSession]'s end and the first scan.
const sessionMargin = Duration(seconds: 10);

/// A short session for a pending-mark test, and when the stack's first
/// pending-mark scan will have reminded staff of it.
///
/// The scan reminds staff only of a session some enrollment covered when it
/// took place (club_server#148): the member must be enrolled at or before
/// its start, and the API cannot backdate an enrollment. So the session is
/// one ahead of now, [sessionLead] away and [sessionLength] long; the test
/// assigns the member before `start` (check it with [assignedBefore]), and
/// the session has ended by the first scan, five minutes after the server
/// starts.
///
/// `scanDeadline` is when that scan will have run, or `null` when the
/// session would not end before it: the stack has been up too long, and the
/// next scan is an hour of ticks away. The bootstrap creates `sudo` just
/// before the server starts, so its `createdAtUtc` dates the stack.
/// [sudoClient] must be signed in as sudo.
Future<({DateTime start, DateTime end, DateTime? scanDeadline})>
pendingMarkSession(SecureClient sudoClient) async {
  final sudo = await sudoClient.auth.getCurrentUser();
  final firstTick = sudo.createdAtUtc.toUtc().add(schedulerTick);
  final now = DateTime.now().toUtc().add(sessionLead);
  // Whole seconds: the server expands occurrence slots on whole seconds.
  final start = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );
  final end = start.add(sessionLength);
  final inTime = end.add(sessionMargin).isBefore(firstTick);
  return (
    start: start,
    end: end,
    scanDeadline: inTime ? firstTick.add(firstScanAllowance) : null,
  );
}

/// Checks that the member's assignments, all made by now, came before the
/// pending-mark session at [start], so their enrollments cover it.
void assignedBefore(DateTime start) {
  expect(
    DateTime.now().toUtc().isBefore(start),
    isTrue,
    reason:
        'The member must be assigned before the session at $start starts, '
        'or no enrollment covers it and the scan sends no reminder; setting '
        'up took longer than $sessionLead.',
  );
}

/// Why a test that needs the pending-mark scan cannot run on this stack.
String pendingMarkScanSkip(int issue, String testFile) =>
    "club_sdk#$issue — the pending-mark scan runs on the scheduler's first "
    'tick, 5 minutes after the server starts, and then hourly, and no API '
    'triggers it. This stack was up before the test could seed its '
    'sessions; run the file on a fresh stack: just test-one $testFile';
