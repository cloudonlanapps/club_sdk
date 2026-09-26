// Issue 32: enrollment, attendance and event-lifecycle rules the server
// enforces, and the SDK's round-trip of occurrence times.
//
// - Attendance and leave are taken only at a time the event's schedule
//   produces; any other time is 422 INVALID_OCCURRENCE_TIME.
// - A rejoin (new invite accepted, or new request approved) clears the old
//   departure, so sessions after it can be marked and are listed.
// - Approving a request runs the member clash gate: 409 TIME_CONFLICT.
// - A member who has already left cannot be removed again: 409 INVALID_STATE.
// - A soft-deleted camp or one-off refuses every mutation with 404.
// - Changing a camp's or one-off's organizer or coaches runs the clash gates.
//   A camp or one-off never blocks on a clash, so the update stands and the
//   clash is reported to the admins as event.conflict_detected, as on create.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// The code the server answers a time that is not one of the event's
/// occurrences with. The SDK has no constant for it; apps see it as a 422.
const _invalidOccurrenceTime = 'INVALID_OCCURRENCE_TIME';

const _password = 'password123';

// Staff.
const _admin = 'test_admin_i32';
const _orgP = 'test_org_p_i32';
const _orgQ = 'test_org_q_i32';
const _orgR = 'test_org_r_i32';
const _orgS1 = 'test_org_s1_i32';
const _orgS2 = 'test_org_s2_i32';
const _orgT = 'test_org_t_i32';
const _busyOrg = 'test_busy_org_i32';
const _busyCoach = 'test_busy_coach_i32';
const _freeCoach = 'test_free_coach_i32';

// Members: one per scenario, so no member is enrolled in two programmes that
// overlap in time (the member gate would refuse the second).
const _mTimesP = 'test_m_times_p_i32';
const _mTimesQ = 'test_m_times_q_i32';
const _mRejoinInvite = 'test_m_rejoin_inv_i32';
const _mRejoinRequest = 'test_m_rejoin_req_i32';
const _mClash = 'test_m_clash_i32';
const _mWithdrawn = 'test_m_withdrawn_i32';
const _mActive = 'test_m_active_i32';
const _mDeleted = 'test_m_deleted_i32';

Matcher _serverError(int status, String code) => throwsA(
  isA<ServerException>()
      .having((e) => e.statusCode, 'statusCode', status)
      .having((e) => e.code, 'code', code),
);

/// The `data` of a notification's `{v, type, data}` payload.
Map<String, dynamic> _data(AppNotification n) =>
    Map<String, dynamic>.from((n.payload['data'] as Map?) ?? const {});

/// [t] truncated to the whole second (UTC). Occurrence slots are expanded on
/// whole seconds.
DateTime _wholeSecond(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

void main() {
  group('Issue 32: enrollment and lifecycle rules', () {
    late SecureClient adminClient;
    final members = <String, SecureClient>{};
    final venues = <String, int>{};

    SecureClient member(String name) => members[name]!;

    setUpAll(() async {
      final setup = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: setup,
        username: sudoUsername,
        password: sudoPassword,
      );
      await setup.auth.login(sudoUsername, sudoPassword);

      Future<void> register(String username, {String? role}) async {
        await registerAndApprove(
          client: setup,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: _password,
          firstName: 'I32',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        if (role != null) await setup.users.assignRole(username, role);
      }

      await register(_admin, role: 'admin');
      for (final coach in [
        _orgP,
        _orgQ,
        _orgR,
        _orgS1,
        _orgS2,
        _orgT,
        _busyOrg,
        _busyCoach,
        _freeCoach,
      ]) {
        await register(coach, role: 'coach');
      }
      // `member` is not a role (#27): a user with no roles is a member.
      const memberNames = [
        _mTimesP,
        _mTimesQ,
        _mRejoinInvite,
        _mRejoinRequest,
        _mClash,
        _mWithdrawn,
        _mActive,
        _mDeleted,
      ];
      for (final m in memberNames) {
        await register(m);
      }
      // Where the credit system is on, joining a programme needs usable
      // credit; elsewhere this does nothing.
      await seedEnrolmentCreditIfGated(setup, memberNames);

      // Every event gets its own venue, so no venue clash muddies a report.
      for (final key in [
        'P',
        'Q',
        'R',
        'S1',
        'S2',
        'W',
        'K',
        'L',
        'block',
        'target',
      ]) {
        final v = await setup.venues.createVenue(name: 'test_Venue I32 $key');
        venues[key] = v.id;
      }
      await setup.auth.logout();

      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login(_admin, _password);
      expect((await adminClient.auth.getCurrentUser()).username, _admin);

      for (final m in memberNames) {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(m, _password);
        members[m] = c;
      }
    });

    tearDownAll(() async {
      for (final c in [adminClient, ...members.values]) {
        try {
          await c.auth.logout();
        } on Exception {
          /* ignore */
        }
      }
    });

    Future<Event> programme(
      String title, {
      required DateTime start,
      required String venue,
      required String organizer,
    }) => adminClient.events.createEvent(
      title: title,
      description: 'I32 fixture',
      type: EventType.programme,
      visibility: Visibility.public,
      venueId: venues[venue]!,
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(hours: 1)),
      rrule: weeklyOn(start),
      organizerName: organizer,
    );

    Future<Event> camp(
      String title, {
      required DateTime start,
      required String venue,
      String? organizer,
      List<String>? coaches,
    }) => adminClient.events.createEvent(
      title: title,
      description: 'I32 fixture',
      type: EventType.camp,
      visibility: Visibility.public,
      venueId: venues[venue]!,
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(hours: 1)),
      rrule: 'FREQ=DAILY;COUNT=2',
      organizerName: organizer,
      coachNames: coaches,
    );

    Future<Event> oneOff(
      String title, {
      required DateTime start,
      required String venue,
      String? organizer,
      List<String>? coaches,
    }) => adminClient.events.createEvent(
      title: title,
      description: 'I32 fixture',
      type: EventType.oneOff,
      visibility: Visibility.public,
      venueId: venues[venue]!,
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(hours: 1)),
      organizerName: organizer,
      coachNames: coaches,
    );

    /// [name]'s enrollment row on [eventId], read through the admin roster.
    Future<Enrollment> enrollmentOf(int eventId, String name) async {
      final roster = await adminClient.enrollments.listEnrollmentsDetailed(
        eventId,
      );
      final row = roster[name];
      expect(row, isNotNull, reason: '$name has an enrollment row');
      return row!;
    }

    /// Every notification [client] holds, newest first.
    Future<List<AppNotification>> allNotifications(SecureClient client) async {
      final all = <AppNotification>[];
      const limit = 100;
      for (var offset = 0; ; offset += limit) {
        final page = await client.notifications.getNotifications(
          offset: offset,
          limit: limit,
        );
        all.addAll(page.items);
        if (page.items.length < limit) break;
      }
      return all;
    }

    // ════════════════════════════════════════════════════════════════════
    // 1. Occurrence times round-trip
    // ════════════════════════════════════════════════════════════════════
    group('occurrence times round-trip', () {
      // P starts in ten minutes, so its first occurrence can be marked
      // (the register opens 30 minutes before) and its later ones can take
      // leave (at least 2 hours ahead).
      late Event p;
      // Q began a week ago, so its second occurrence is the one in fifteen
      // minutes: a later occurrence that can be marked.
      late Event q;
      late List<Occurrence> pOccs;
      late List<Occurrence> qOccs;

      setUpAll(() async {
        final now = nowUtcMinute();
        p = await programme(
          'test_I32 times P',
          start: now.add(const Duration(minutes: 10)),
          venue: 'P',
          organizer: _orgP,
        );
        q = await programme(
          'test_I32 times Q',
          start: now
              .add(const Duration(minutes: 15))
              .subtract(const Duration(days: 7)),
          venue: 'Q',
          organizer: _orgQ,
        );
        await adminClient.enrollments.assign(p.id, _mTimesP);
        await adminClient.enrollments.assign(q.id, _mTimesQ);

        // The times come from the server's own occurrence listing.
        final listed = await adminClient.occurrences.listOccurrences(
          fromTimeUtc: q.startTimeUtc.subtract(const Duration(minutes: 1)),
          toTimeUtc: now.add(const Duration(days: 22)),
          eventType: EventType.programme,
          limit: 100,
        );
        List<Occurrence> of(Event e) =>
            listed.where((o) => o.eventId == e.id).toList()..sort(
              (a, b) =>
                  a.originalStartTimeUtc.compareTo(b.originalStartTimeUtc),
            );
        pOccs = of(p);
        qOccs = of(q);
      });

      test('the listing yields the schedule slots of both programmes', () {
        expect(pOccs.length, greaterThanOrEqualTo(3));
        expect(pOccs.first.originalStartTimeUtc, p.startTimeUtc);
        expect(
          pOccs[1].originalStartTimeUtc,
          p.startTimeUtc.add(const Duration(days: 7)),
        );
        expect(qOccs.length, greaterThanOrEqualTo(3));
        expect(qOccs.first.originalStartTimeUtc, q.startTimeUtc);
        expect(
          qOccs[1].originalStartTimeUtc,
          q.startTimeUtc.add(const Duration(days: 7)),
        );
      });

      test('marking at a listed first and later occurrence succeeds', () async {
        final first = pOccs.first.originalStartTimeUtc;
        final pReport = await adminClient.attendance.markAttendance(
          p.id,
          first,
          const [
            AttendanceMarkRecord(
              membername: _mTimesP,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(pReport.marked.map((m) => m.membername), [_mTimesP]);
        expect(pReport.refused, isEmpty);

        final later = qOccs[1].originalStartTimeUtc;
        final qReport = await adminClient.attendance.markAttendance(
          q.id,
          later,
          const [
            AttendanceMarkRecord(
              membername: _mTimesQ,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(qReport.marked.map((m) => m.membername), [_mTimesQ]);
        expect(qReport.refused, isEmpty);

        // The records are keyed on exactly the listed times.
        final pRecords = await adminClient.attendance
            .getAttendanceForOccurrence(p.id, first);
        expect(
          pRecords.where(
            (r) =>
                r.membername == _mTimesP &&
                r.status == AttendanceStatus.present,
          ),
          hasLength(1),
        );
        final qRecords = await adminClient.attendance
            .getAttendanceForOccurrence(q.id, later);
        expect(
          qRecords.where(
            (r) =>
                r.membername == _mTimesQ &&
                r.status == AttendanceStatus.present,
          ),
          hasLength(1),
        );
      });

      test('marking at a shifted time is 422', () async {
        const record = [
          AttendanceMarkRecord(
            membername: _mTimesP,
            status: AttendanceStatus.present,
          ),
        ];
        final first = pOccs.first.originalStartTimeUtc;
        // Shifts that keep the register open (it opens 30 minutes before a
        // start), so the refusal is the time check and nothing else.
        for (final shift in const [
          Duration(seconds: 1),
          Duration(minutes: 1),
          Duration(hours: -1),
        ]) {
          await expectLater(
            adminClient.attendance.markAttendance(
              p.id,
              first.add(shift),
              record,
            ),
            _serverError(422, _invalidOccurrenceTime),
            reason: 'P first occurrence shifted by $shift',
          );
        }
        await expectLater(
          adminClient.attendance.markAttendance(
            q.id,
            qOccs[1].originalStartTimeUtc.add(const Duration(minutes: 1)),
            const [
              AttendanceMarkRecord(
                membername: _mTimesQ,
                status: AttendanceStatus.present,
              ),
            ],
          ),
          _serverError(422, _invalidOccurrenceTime),
        );
      });

      test('leave at a listed later occurrence succeeds', () async {
        final pLater = pOccs[1].originalStartTimeUtc;
        await member(
          _mTimesP,
        ).myEvents.requestLeave(_mTimesP, p.id, pLater, reason: 'away');
        final pRecord = await member(
          _mTimesP,
        ).myEvents.getMyOccurrenceAttendance(_mTimesP, p.id, pLater);
        expect(pRecord?.status, AttendanceStatus.onLeaveRequested);

        final qLater = qOccs[2].originalStartTimeUtc;
        await member(
          _mTimesQ,
        ).myEvents.requestLeave(_mTimesQ, q.id, qLater, reason: 'away');
        final qRecord = await member(
          _mTimesQ,
        ).myEvents.getMyOccurrenceAttendance(_mTimesQ, q.id, qLater);
        expect(qRecord?.status, AttendanceStatus.onLeaveRequested);
      });

      test('leave at a shifted time is 422', () async {
        final pLater = pOccs[2].originalStartTimeUtc;
        for (final shift in const [Duration(seconds: 1), Duration(hours: 1)]) {
          await expectLater(
            member(
              _mTimesP,
            ).myEvents.requestLeave(_mTimesP, p.id, pLater.add(shift)),
            _serverError(422, _invalidOccurrenceTime),
            reason: 'P later occurrence shifted by $shift',
          );
        }
        await expectLater(
          member(_mTimesQ).myEvents.requestLeave(
            _mTimesQ,
            q.id,
            qOccs[3].originalStartTimeUtc.add(const Duration(hours: 1)),
          ),
          _serverError(422, _invalidOccurrenceTime),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════
    // 2. Rejoin
    // ════════════════════════════════════════════════════════════════════
    group('rejoin', () {
      // R's first session starts shortly, so both members leave and rejoin
      // before it starts and the register is marked after it has started:
      // a past session is covered only by the stint the member was in at
      // the time, which is what a stale departure date used to cut short.
      late Event r;
      late Enrollment inviteWithdrawn;
      late Enrollment inviteReinvited;
      late Enrollment inviteRejoined;
      late Enrollment requestWithdrawn;
      late Enrollment requestRequested;
      late Enrollment requestRejoined;
      late DateTime rejoinsDoneAt;

      Future<void> enrollThenLeave(String name) async {
        await adminClient.enrollments.assign(r.id, name);
        await member(name).myEvents.withdraw(name, r.id, reason: 'moving');
        await adminClient.enrollments.approveWithdraw(r.id, name);
      }

      setUpAll(() async {
        r = await programme(
          'test_I32 rejoin R',
          start: _wholeSecond(DateTime.now().add(const Duration(seconds: 45))),
          venue: 'R',
          organizer: _orgR,
        );

        // Path 1: a new invitation, accepted.
        await enrollThenLeave(_mRejoinInvite);
        inviteWithdrawn = await enrollmentOf(
          r.id,
          _mRejoinInvite,
        );
        await adminClient.enrollments.invite(r.id, _mRejoinInvite);
        inviteReinvited = await enrollmentOf(
          r.id,
          _mRejoinInvite,
        );
        await member(
          _mRejoinInvite,
        ).myEvents.acceptInvite(_mRejoinInvite, r.id);
        inviteRejoined = await enrollmentOf(
          r.id,
          _mRejoinInvite,
        );

        // Path 2: a new request, approved.
        await enrollThenLeave(_mRejoinRequest);
        requestWithdrawn = await enrollmentOf(
          r.id,
          _mRejoinRequest,
        );
        await member(
          _mRejoinRequest,
        ).myEvents.requestToJoin(_mRejoinRequest, r.id);
        requestRequested = await enrollmentOf(
          r.id,
          _mRejoinRequest,
        );
        await adminClient.enrollments.approveRequest(r.id, _mRejoinRequest);
        requestRejoined = await enrollmentOf(
          r.id,
          _mRejoinRequest,
        );
        rejoinsDoneAt = DateTime.now().toUtc();
      });

      test('accepting a new invite starts a fresh stint', () {
        expect(inviteWithdrawn.status, EnrollmentStatus.withdrawn);
        expect(inviteWithdrawn.withdrawnAtUtc, isNotNull);
        // An invitation alone leaves the closed stint as it was.
        expect(inviteReinvited.status, EnrollmentStatus.invited);
        expect(inviteReinvited.withdrawnAtUtc, inviteWithdrawn.withdrawnAtUtc);
        expect(inviteRejoined.status, EnrollmentStatus.accepted);
        expect(inviteRejoined.withdrawnAtUtc, isNull);
        expect(inviteRejoined.withdrawalReason, isNull);
      });

      test('having a new request approved starts a fresh stint', () {
        expect(requestWithdrawn.status, EnrollmentStatus.withdrawn);
        expect(requestWithdrawn.withdrawnAtUtc, isNotNull);
        expect(requestRequested.status, EnrollmentStatus.requested);
        expect(requestRejoined.status, EnrollmentStatus.accepted);
        expect(requestRejoined.withdrawnAtUtc, isNull);
        expect(requestRejoined.withdrawalReason, isNull);
      });

      test(
        'a session after the rejoin is marked and in the member listing',
        () async {
          final session = r.startTimeUtc;
          expect(
            rejoinsDoneAt.isBefore(session),
            isTrue,
            reason: 'both rejoins must land before the session starts',
          );
          // Mark once the session has started, so it is a past session.
          final wait = session
              .add(const Duration(seconds: 2))
              .difference(DateTime.now().toUtc());
          if (!wait.isNegative) await Future<void>.delayed(wait);

          final report = await adminClient.attendance.markAttendance(
            r.id,
            session,
            const [
              AttendanceMarkRecord(
                membername: _mRejoinInvite,
                status: AttendanceStatus.present,
              ),
              AttendanceMarkRecord(
                membername: _mRejoinRequest,
                status: AttendanceStatus.present,
              ),
            ],
          );
          expect(
            report.marked.map((m) => m.membername),
            unorderedEquals([_mRejoinInvite, _mRejoinRequest]),
          );
          expect(report.refused, isEmpty);

          for (final name in [_mRejoinInvite, _mRejoinRequest]) {
            final client = member(name);
            final from = session.subtract(const Duration(hours: 1));
            final to = session.add(const Duration(hours: 2));

            final attendance = await client.myEvents.listMyAttendance(
              name,
              fromTimeUtc: from,
              toTimeUtc: to,
            );
            expect(
              attendance.where(
                (a) =>
                    a.eventId == r.id &&
                    a.occurrenceTimeUtc == session &&
                    a.status == AttendanceStatus.present,
              ),
              hasLength(1),
              reason: '$name sees their mark',
            );

            final occurrences = await client.myEvents.listMyOccurrences(
              name,
              fromTimeUtc: from,
              toTimeUtc: to,
            );
            expect(
              occurrences.where(
                (o) => o.eventId == r.id && o.originalStartTimeUtc == session,
              ),
              hasLength(1),
              reason: '$name sees the session',
            );
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    });

    // ════════════════════════════════════════════════════════════════════
    // 3. Clashing request approval
    // ════════════════════════════════════════════════════════════════════
    group('clashing request approval', () {
      late Event s1;
      late Event s2;

      setUpAll(() async {
        final slot = dayAt(20);
        s1 = await programme(
          'test_I32 clash S1',
          start: slot,
          venue: 'S1',
          organizer: _orgS1,
        );
        s2 = await programme(
          'test_I32 clash S2',
          start: slot,
          venue: 'S2',
          organizer: _orgS2,
        );
      });

      test('approving the second of two same-slot requests is 409', () async {
        final c = member(_mClash);
        // A request does not count against another request.
        await c.myEvents.requestToJoin(_mClash, s1.id);
        await c.myEvents.requestToJoin(_mClash, s2.id);

        await adminClient.enrollments.approveRequest(s1.id, _mClash);
        expect(
          await adminClient.enrollments.getEnrollmentStatus(s1.id, _mClash),
          EnrollmentStatus.accepted,
        );

        await expectLater(
          adminClient.enrollments.approveRequest(s2.id, _mClash),
          _serverError(409, SdkErrorCode.timeConflict),
        );
        expect(
          await adminClient.enrollments.getEnrollmentStatus(s2.id, _mClash),
          EnrollmentStatus.requested,
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════
    // 4. Removing a withdrawn member
    // ════════════════════════════════════════════════════════════════════
    group('removal', () {
      late Event w;

      setUpAll(() async {
        w = await oneOff('test_I32 removal W', start: dayAt(30), venue: 'W');
      });

      test(
        'removing a member who withdrew is 409 and keeps the date',
        () async {
          await adminClient.enrollments.assign(w.id, _mWithdrawn);
          await member(
            _mWithdrawn,
          ).myEvents.withdraw(_mWithdrawn, w.id, reason: 'injured');
          await adminClient.enrollments.approveWithdraw(w.id, _mWithdrawn);
          final before = await enrollmentOf(
            w.id,
            _mWithdrawn,
          );
          expect(before.status, EnrollmentStatus.withdrawn);
          expect(before.withdrawnAtUtc, isNotNull);

          await expectLater(
            adminClient.enrollments.removeEnrollment(
              w.id,
              _mWithdrawn,
              reason: 'tidy up',
            ),
            _serverError(409, SdkErrorCode.invalidState),
          );

          final after = await enrollmentOf(
            w.id,
            _mWithdrawn,
          );
          expect(after.status, EnrollmentStatus.withdrawn);
          expect(after.withdrawnAtUtc, before.withdrawnAtUtc);
          expect(after.withdrawalReason, before.withdrawalReason);
        },
      );

      test('removing an active member works', () async {
        await adminClient.enrollments.assign(w.id, _mActive);
        await adminClient.enrollments.removeEnrollment(
          w.id,
          _mActive,
          reason: 'no longer training',
        );
        final e = await enrollmentOf(w.id, _mActive);
        expect(e.status, EnrollmentStatus.removed);
        expect(e.withdrawnAtUtc, isNotNull);
      });
    });

    // ════════════════════════════════════════════════════════════════════
    // 5. Deleted camp / one-off
    // ════════════════════════════════════════════════════════════════════
    group('deleted camp and one-off', () {
      late Event k;
      late Event l;
      late int lOccurrenceVersion;

      setUpAll(() async {
        k = await camp('test_I32 deleted camp K', start: dayAt(40), venue: 'K');
        l = await oneOff(
          'test_I32 deleted one-off L',
          start: dayAt(45),
          venue: 'L',
        );
        await adminClient.enrollments.assign(k.id, _mDeleted);
        await adminClient.enrollments.assign(l.id, _mDeleted);
        lOccurrenceVersion = await occurrenceVersion(
          adminClient,
          l.id,
          l.startTimeUtc,
        );
        await adminClient.events.deleteEvent(k.id);
        await adminClient.events.deleteEvent(l.id);
      });

      /// Runs [attempts] and checks the enrolled member was told of the
      /// deletion of [event] but hears nothing from the refused attempts.
      Future<void> expectSilent(
        Event event,
        Future<void> Function() attempts,
      ) async {
        final c = member(_mDeleted);
        final before = await allNotifications(c);
        expect(
          before.where(
            (n) =>
                n.type == NotificationType.eventDeleted &&
                _data(n)['eventId'] == event.id,
          ),
          hasLength(1),
          reason: 'the member was told of the deletion',
        );
        await attempts();
        final after = await allNotifications(c);
        expect(
          after.map((n) => n.id).toSet(),
          before.map((n) => n.id).toSet(),
          reason: 'a refused attempt notifies nobody',
        );
      }

      test('cancel, reschedule and update of a deleted camp are 404', () async {
        await expectSilent(k, () async {
          await expectLater(
            adminClient.events.cancelSeries(
              k.id,
              reason: 'no ice',
              effectiveDateTimeUtc: k.startTimeUtc.add(const Duration(days: 1)),
            ),
            _serverError(404, SdkErrorCode.eventNotFound),
          );
          await expectLater(
            adminClient.events.rescheduleEvent(
              k.id,
              version: k.version,
              startTimeUtc: k.startTimeUtc.add(const Duration(hours: 2)),
            ),
            _serverError(404, SdkErrorCode.eventNotFound),
          );
          await expectLater(
            adminClient.events.updateEvent(
              k.id,
              version: k.version,
              title: 'test_I32 deleted camp K renamed',
            ),
            _serverError(404, SdkErrorCode.eventNotFound),
          );
        });

        final deleted = await adminClient.events.listDeletedEvents(limit: 100);
        final stored = deleted.singleWhere((e) => e.id == k.id);
        expect(stored.title, k.title);
        expect(stored.startTimeUtc, k.startTimeUtc);
        expect(stored.untilTimeUtc, isNull);
      });

      test(
        'drop, cancel, reschedule and update of a deleted one-off are 404',
        () async {
          await expectSilent(l, () async {
            await expectLater(
              adminClient.events.drop(
                l.id,
                version: lOccurrenceVersion,
                reason: 'no ice',
              ),
              _serverError(404, SdkErrorCode.eventNotFound),
            );
            await expectLater(
              adminClient.events.cancelSeries(
                l.id,
                reason: 'no ice',
                effectiveDateTimeUtc: l.startTimeUtc,
              ),
              _serverError(404, SdkErrorCode.eventNotFound),
            );
            await expectLater(
              adminClient.events.rescheduleEvent(
                l.id,
                version: l.version,
                startTimeUtc: l.startTimeUtc.add(const Duration(hours: 2)),
              ),
              _serverError(404, SdkErrorCode.eventNotFound),
            );
            await expectLater(
              adminClient.events.updateEvent(
                l.id,
                version: l.version,
                title: 'test_I32 deleted one-off L renamed',
              ),
              _serverError(404, SdkErrorCode.eventNotFound),
            );
          });

          final deleted = await adminClient.events.listDeletedEvents(
            limit: 100,
          );
          final stored = deleted.singleWhere((e) => e.id == l.id);
          expect(stored.title, l.title);
          expect(stored.startTimeUtc, l.startTimeUtc);
        },
      );
    });

    // ════════════════════════════════════════════════════════════════════
    // 6. Organizer / coach change on update
    // ════════════════════════════════════════════════════════════════════
    group('staff change on update', () {
      // Each target sits on its own days at its own venue, organized by
      // _orgT; each blocker shares a target's time, not its venue, and is
      // organized by _busyOrg and coached by _busyCoach. The targets are
      // three days apart, so they never clash with each other.
      var day = 50;
      DateTime nextSlot() {
        final s = dayAt(day);
        day += 3;
        return s;
      }

      Future<Event> blockerAt(DateTime start, String tag) => oneOff(
        'test_I32 blocker $tag',
        start: start,
        venue: 'block',
        organizer: _busyOrg,
        coaches: const [_busyCoach],
      );

      /// The `event.conflict_detected` notices the admin holds for [event].
      Future<List<AppNotification>> conflictNotices(Event event) async =>
          (await allNotifications(adminClient))
              .where(
                (n) =>
                    n.type == NotificationType.eventConflictDetected &&
                    _data(n)['eventId'] == event.id,
              )
              .toList();

      List<Object?> conflictingIds(List<AppNotification> notices) => [
        for (final n in notices)
          for (final c in (_data(n)['conflictingEvents'] as List? ?? const []))
            (c as Map)['eventId'],
      ];

      test(
        'a camp given a busy organizer is updated and the clash reported',
        () async {
          final start = nextSlot();
          final target = await camp(
            'test_I32 camp organizer clash',
            start: start,
            venue: 'target',
            organizer: _orgT,
          );
          final blocker = await blockerAt(start, 'camp organizer');
          expect(await conflictNotices(target), isEmpty);

          final updated = await adminClient.events.updateEvent(
            target.id,
            version: target.version,
            organizerName: _busyOrg,
          );
          expect(updated.organizerName, _busyOrg);
          expect(
            (await adminClient.events.getEvent(target.id)).organizerName,
            _busyOrg,
          );
          final notices = await conflictNotices(target);
          expect(notices, isNotEmpty);
          expect(conflictingIds(notices), contains(blocker.id));
        },
      );

      test(
        'a one-off given a busy organizer is updated and the clash reported',
        () async {
          final start = nextSlot();
          final target = await oneOff(
            'test_I32 one-off organizer clash',
            start: start,
            venue: 'target',
            organizer: _orgT,
          );
          final blocker = await blockerAt(start, 'one-off organizer');
          expect(await conflictNotices(target), isEmpty);

          final updated = await adminClient.events.updateEvent(
            target.id,
            version: target.version,
            organizerName: _busyOrg,
          );
          expect(updated.organizerName, _busyOrg);
          final notices = await conflictNotices(target);
          expect(notices, isNotEmpty);
          expect(conflictingIds(notices), contains(blocker.id));
        },
      );

      test(
        'a camp given a busy coach is updated and the clash reported',
        () async {
          final start = nextSlot();
          final target = await camp(
            'test_I32 camp coach clash',
            start: start,
            venue: 'target',
            organizer: _orgT,
          );
          final blocker = await blockerAt(start, 'camp coach');
          expect(await conflictNotices(target), isEmpty);

          final updated = await adminClient.events.updateEvent(
            target.id,
            version: target.version,
            coachNames: () => [_busyCoach],
          );
          expect(updated.coachNames, [_busyCoach]);
          final notices = await conflictNotices(target);
          expect(notices, isNotEmpty);
          expect(conflictingIds(notices), contains(blocker.id));
        },
      );

      test(
        'a one-off given a busy coach is updated and the clash reported',
        () async {
          final start = nextSlot();
          final target = await oneOff(
            'test_I32 one-off coach clash',
            start: start,
            venue: 'target',
            organizer: _orgT,
          );
          final blocker = await blockerAt(start, 'one-off coach');
          expect(await conflictNotices(target), isEmpty);

          final updated = await adminClient.events.updateEvent(
            target.id,
            version: target.version,
            coachNames: () => [_busyCoach],
          );
          expect(updated.coachNames, [_busyCoach]);
          final notices = await conflictNotices(target);
          expect(notices, isNotEmpty);
          expect(conflictingIds(notices), contains(blocker.id));
        },
      );

      test(
        'a free organizer and coach are accepted with nothing reported',
        () async {
          final campStart = nextSlot();
          final campTarget = await camp(
            'test_I32 camp free staff',
            start: campStart,
            venue: 'target',
            organizer: _orgT,
          );
          // A busy person elsewhere at the same time, so the gates have
          // something to find if they looked at the wrong person.
          await blockerAt(campStart, 'camp free');
          final oneOffStart = nextSlot();
          final oneOffTarget = await oneOff(
            'test_I32 one-off free staff',
            start: oneOffStart,
            venue: 'target',
            organizer: _orgT,
          );
          await blockerAt(oneOffStart, 'one-off free');

          for (final target in [campTarget, oneOffTarget]) {
            final updated = await adminClient.events.updateEvent(
              target.id,
              version: target.version,
              organizerName: _freeCoach,
              coachNames: () => [_freeCoach],
            );
            expect(updated.organizerName, _freeCoach);
            expect(updated.coachNames, [_freeCoach]);
            expect(
              await conflictNotices(target),
              isEmpty,
              reason: '${target.title}: a free person clashes with nothing',
            );
          }
        },
      );
    });
  });
}
