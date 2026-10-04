import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

UserPrivate _user({required bool isSuperAdmin}) => UserPrivate(
  username: 'u',
  displayName: 'u',
  status: UserStatus.active,
  isSuperAdmin: isSuperAdmin,
  roles: const UserRoles(),
  createdAtUtc: DateTime.utc(2024),
);

Event _event({
  EventType type = EventType.programme,
  DateTime? startTimeUtc,
  DateTime? endTimeUtc,
  DateTime? untilTimeUtc,
  String? rrule,
}) => Event(
  id: 1,
  title: 't',
  description: '',
  type: type,
  visibility: Visibility.public,
  venueId: 1,
  startTimeUtc: startTimeUtc ?? DateTime.utc(2030),
  endTimeUtc: endTimeUtc ?? DateTime.utc(2030, 1, 1, 1),
  createdAtUtc: DateTime.utc(2024),
  updatedAtUtc: DateTime.utc(2024),
  untilTimeUtc: untilTimeUtc,
  rrule: rrule,
);

void main() {
  // After round-2, `canMarkAttendanceNow` reads `DateTime.now().toUtc()`
  // directly and no longer accepts a `now` override. Tests below compute
  // window-relative timestamps from `DateTime.now()` and are stable for
  // any wall-clock instant — the few "exactly at boundary" cases are
  // skipped since they require clock control we deliberately removed.
  group('canMarkAttendanceNow', () {
    test('rejects more than 30 minutes before effective start', () {
      final now = DateTime.now().toUtc();
      final start = now.add(const Duration(hours: 1));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: false),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: start.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('allows inside the window (during the session)', () {
      final now = DateTime.now().toUtc();
      // Session that started 10 min ago and ends in 50 min.
      final start = now.subtract(const Duration(minutes: 10));
      final end = now.add(const Duration(minutes: 50));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: false),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: end,
        ),
        isTrue,
      );
    });

    test('rejects after the edit window closes', () {
      final now = DateTime.now().toUtc();
      final end = now.subtract(const Duration(days: 16));
      final start = end.subtract(const Duration(hours: 1));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: false),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: end,
        ),
        isFalse,
      );
    });

    test('Issue 309: super-admin rejected before the open window '
        '(no fabricating future attendance)', () {
      final now = DateTime.now().toUtc();
      final start = now.add(const Duration(days: 7));
      final end = start.add(const Duration(hours: 1));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: true),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: end,
        ),
        isFalse,
      );
    });

    test('Issue 309: super-admin allowed after the edit window closes '
        '(audit correction)', () {
      final now = DateTime.now().toUtc();
      final end = now.subtract(const Duration(days: 30));
      final start = end.subtract(const Duration(hours: 1));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: true),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: end,
        ),
        isTrue,
      );
    });

    test('Issue 309: super-admin allowed inside the normal window', () {
      final now = DateTime.now().toUtc();
      final start = now.subtract(const Duration(minutes: 10));
      final end = now.add(const Duration(minutes: 50));
      expect(
        canMarkAttendanceNow(
          actingUser: _user(isSuperAdmin: true),
          effectiveStartTimeUtc: start,
          effectiveEndTimeUtc: end,
        ),
        isTrue,
      );
    });
  });

  group('isEventSeriesCancelled', () {
    test('false when untilTimeUtc is null', () {
      expect(isEventSeriesCancelled(_event()), isFalse);
    });

    test('true when untilTimeUtc is set and has passed', () {
      expect(
        isEventSeriesCancelled(
          _event(untilTimeUtc: DateTime.utc(2020, 6)),
        ),
        isTrue,
      );
    });

    test('Issue 16: false while the cutoff is still ahead', () {
      expect(
        isEventSeriesCancelled(
          _event(untilTimeUtc: DateTime.utc(2030, 6)),
          now: DateTime.utc(2030, 5),
        ),
        isFalse,
      );
    });

    test('Issue 16: true once the cutoff is reached', () {
      expect(
        isEventSeriesCancelled(
          _event(untilTimeUtc: DateTime.utc(2030, 6)),
          now: DateTime.utc(2030, 6),
        ),
        isTrue,
      );
    });
  });

  group('canEnrollOnEvent', () {
    final futureEvent = _event(
      startTimeUtc: DateTime.utc(2030),
      endTimeUtc: DateTime.utc(2030, 1, 1, 2),
    );
    final pastEvent = _event(
      startTimeUtc: DateTime.utc(2020),
      endTimeUtc: DateTime.utc(2020, 1, 1, 2),
    );
    final cancelledEvent = _event(
      type: EventType.camp,
      startTimeUtc: DateTime.utc(2030),
      endTimeUtc: DateTime.utc(2030, 1, 1, 2),
      untilTimeUtc: DateTime.utc(2030, 6),
    );

    test('allows on future, active event', () {
      expect(
        canEnrollOnEvent(futureEvent, _user(isSuperAdmin: false)),
        isTrue,
      );
    });

    test('rejects on past event', () {
      expect(
        canEnrollOnEvent(pastEvent, _user(isSuperAdmin: false)),
        isFalse,
      );
    });

    test('rejects on cancelled series once its cutoff is reached', () {
      expect(
        canEnrollOnEvent(
          cancelledEvent,
          _user(isSuperAdmin: false),
          now: DateTime.utc(2030, 6),
        ),
        isFalse,
      );
    });

    test('Issue 16: a bounded series still enrolls before its cutoff', () {
      expect(
        canEnrollOnEvent(
          cancelledEvent,
          _user(isSuperAdmin: false),
          now: DateTime.utc(2029, 12),
        ),
        isTrue,
      );
    });

    test('super-admin bypasses past gate', () {
      expect(
        canEnrollOnEvent(pastEvent, _user(isSuperAdmin: true)),
        isTrue,
      );
    });

    test('super-admin bypasses cancelled-series gate', () {
      expect(
        canEnrollOnEvent(cancelledEvent, _user(isSuperAdmin: true)),
        isTrue,
      );
    });
  });

  group('canAssignTrial', () {
    final user = _user(isSuperAdmin: false);

    test('allows on active programme', () {
      expect(canAssignTrial(_event(), user), isTrue);
    });

    test('rejects on camp', () {
      expect(canAssignTrial(_event(type: EventType.camp), user), isFalse);
    });

    test('rejects on one-off', () {
      expect(canAssignTrial(_event(type: EventType.oneOff), user), isFalse);
    });

    test('rejects when programme series is cancelled', () {
      expect(
        canAssignTrial(
          _event(
            untilTimeUtc: DateTime.utc(2030, 6),
          ),
          user,
          now: DateTime.utc(2030, 7),
        ),
        isFalse,
      );
    });

    test(
      'super-admin still blocked on non-programme (server enforces type)',
      () {
        expect(
          canAssignTrial(
            _event(type: EventType.camp),
            _user(isSuperAdmin: true),
          ),
          isFalse,
        );
      },
    );
  });

  group('mapEnrollmentMutationError', () {
    test('maps INVALID_EVENT_TYPE to a programme-only message', () {
      final msg = mapEnrollmentMutationError(
        const ServerException(
          statusCode: 400,
          code: SdkErrorCode.invalidEventType,
          message: 'raw',
        ),
      );
      expect(msg, contains('programme'));
    });

    test('maps INVALID_STATE to a state-aware message', () {
      final msg = mapEnrollmentMutationError(
        const ServerException(
          statusCode: 422,
          code: SdkErrorCode.invalidState,
          message: 'raw',
        ),
      );
      expect(msg, contains('no longer open'));
    });
  });

  group('mapAttendanceMutationError', () {
    test('maps ATTENDANCE_NOT_YET_OPEN to a clear message', () {
      final msg = mapAttendanceMutationError(
        const ServerException(
          statusCode: 422,
          code: SdkErrorCode.attendanceNotYetOpen,
          message: 'raw server message',
        ),
      );
      expect(msg, contains('30 minutes'));
    });

    test('maps EDIT_WINDOW_CLOSED to a clear message', () {
      final msg = mapAttendanceMutationError(
        const ServerException(
          statusCode: 422,
          code: SdkErrorCode.editWindowClosed,
          message: 'raw server message',
        ),
      );
      expect(msg, contains('edit window'));
    });
  });

  group('Issue 686: isPastEvent for recurring series uses rrule, not '
      'first-occurrence endTimeUtc', () {
    // The customer-visible scenario: National Championship Camp is a
    // 5-day camp with rrule FREQ=DAILY;COUNT=5. Each occurrence runs
    // 06:00–07:00 UTC. The Event row stores startTimeUtc / endTimeUtc
    // of the FIRST occurrence only. Without this fix, isPastEvent
    // returned true after the first day ended, hiding "Request to Join"
    // for the rest of the camp.

    test('one-off (no rrule): isPastEvent uses endTimeUtc directly', () {
      final past = _event(
        startTimeUtc: DateTime.utc(2020, 1, 1, 6),
        endTimeUtc: DateTime.utc(2020, 1, 1, 7),
      );
      final future = _event(
        startTimeUtc: DateTime.utc(2099, 1, 1, 6),
        endTimeUtc: DateTime.utc(2099, 1, 1, 7),
      );
      expect(isPastEvent(past), isTrue);
      expect(isPastEvent(future), isFalse);
    });

    test('camp FREQ=DAILY;COUNT=5: NOT past while series still has '
        'future occurrences (the bug)', () {
      // Series: day 1..day 5, each 06:00–07:00 UTC.
      // "now" = day 3 at 06:30 UTC — middle of day 3's occurrence.
      // Pre-fix this returned true (endTimeUtc of day 1 < now).
      // Post-fix: false (day 5's end > now).
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      final dayThreeMid = DateTime.utc(2030, 6, 3, 6, 30);
      expect(
        isPastEvent(event, now: dayThreeMid),
        isFalse,
        reason: 'Series runs days 1-5; day-3 mid-occurrence is not past.',
      );
    });

    test('camp FREQ=DAILY;COUNT=5: NOT past on the LAST day mid-session', () {
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      final dayFiveMid = DateTime.utc(2030, 6, 5, 6, 30);
      expect(isPastEvent(event, now: dayFiveMid), isFalse);
    });

    test('camp FREQ=DAILY;COUNT=5: IS past after the last occurrence ends', () {
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      // 2030-06-06 — one full day after the day-5 session.
      final afterSeries = DateTime.utc(2030, 6, 6);
      expect(isPastEvent(event, now: afterSeries), isTrue);
    });

    test('canEnrollOnEvent on mid-run camp: allows non-super-admin '
        '(regression for hidden Request-to-Join)', () {
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      // Day 3 — pre-fix would have blocked enrollment.
      // Note: canEnrollOnEvent reads `DateTime.now()` indirectly; we
      // verify the underlying gate via isPastEvent which takes `now:`.
      expect(isPastEvent(event, now: DateTime.utc(2030, 6, 3, 12)), isFalse);
    });

    test('rrule that parses to empty (defensive): falls back to '
        'endTimeUtc', () {
      // Empty rrule string => parsed.isEmpty path => endTimeUtc fallback.
      final event = _event(
        startTimeUtc: DateTime.utc(2020, 1, 1, 6),
        endTimeUtc: DateTime.utc(2020, 1, 1, 7),
        rrule: '',
      );
      expect(isPastEvent(event), isTrue);
    });

    test('lastOccurrenceEndUtc: oneoff returns endTimeUtc', () {
      final event = _event(
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
      );
      expect(lastOccurrenceEndUtc(event), DateTime.utc(2030, 6, 1, 7));
    });

    test('lastOccurrenceEndUtc: camp series end = day 5 + 1h session', () {
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      expect(lastOccurrenceEndUtc(event), DateTime.utc(2030, 6, 5, 7));
    });

    test('Issue 688: camp FREQ=DAILY;COUNT=5, cancelled mid-series at day 3: '
        'lastOccurrenceEndUtc = day 3 end (not day 5)', () {
      final event = _event(
        type: EventType.camp,
        startTimeUtc: DateTime.utc(2030, 6, 1, 6),
        endTimeUtc: DateTime.utc(2030, 6, 1, 7),
        rrule: 'FREQ=DAILY;COUNT=5',
        untilTimeUtc: DateTime.utc(2030, 6, 3, 7), // cancelled at day 3 end
      );
      expect(lastOccurrenceEndUtc(event), DateTime.utc(2030, 6, 3, 7));
    });
  });

  group('enrollmentCoversOccurrence', () {
    final now = DateTime.utc(2030, 6, 15);

    Enrollment enrollment({
      EnrollmentStatus status = EnrollmentStatus.assigned,
      DateTime? enrolledAtUtc,
      DateTime? withdrawnAtUtc,
    }) => Enrollment(
      id: 1,
      membername: 'alice',
      eventId: 1,
      status: status,
      createdAtUtc: DateTime.utc(2030),
      enrolledAtUtc: enrolledAtUtc,
      withdrawnAtUtc: withdrawnAtUtc,
    );

    final future = now.add(const Duration(days: 1));
    final past = now.subtract(const Duration(days: 5));

    test('future occurrence: active status covers', () {
      for (final s in [
        EnrollmentStatus.invited,
        EnrollmentStatus.requested,
        EnrollmentStatus.accepted,
        EnrollmentStatus.assigned,
        EnrollmentStatus.assignedTrial,
        EnrollmentStatus.withdrawRequested,
      ]) {
        expect(
          enrollmentCoversOccurrence(
            enrollment(status: s),
            future,
            now: now,
          ),
          isTrue,
          reason: '$s should cover a future occurrence',
        );
      }
    });

    test('future occurrence: terminal status does not cover', () {
      for (final s in [EnrollmentStatus.rejected, EnrollmentStatus.withdrawn]) {
        expect(
          enrollmentCoversOccurrence(
            enrollment(status: s),
            future,
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('past occurrence: enrolled before, never withdrawn → covers', () {
      expect(
        enrollmentCoversOccurrence(
          enrollment(enrolledAtUtc: past.subtract(const Duration(days: 1))),
          past,
          now: now,
        ),
        isTrue,
      );
    });

    test('past occurrence: enrolled after the occurrence → not covered', () {
      expect(
        enrollmentCoversOccurrence(
          enrollment(enrolledAtUtc: past.add(const Duration(days: 1))),
          past,
          now: now,
        ),
        isFalse,
      );
    });

    test('past occurrence: no enrolledAt → not covered', () {
      expect(
        enrollmentCoversOccurrence(enrollment(), past, now: now),
        isFalse,
      );
    });

    test('past occurrence: withdrawn before the occurrence → not covered', () {
      expect(
        enrollmentCoversOccurrence(
          enrollment(
            enrolledAtUtc: past.subtract(const Duration(days: 2)),
            withdrawnAtUtc: past.subtract(const Duration(days: 1)),
          ),
          past,
          now: now,
        ),
        isFalse,
      );
    });

    test('past occurrence: withdrawn after the occurrence → still covers', () {
      expect(
        enrollmentCoversOccurrence(
          enrollment(
            enrolledAtUtc: past.subtract(const Duration(days: 2)),
            withdrawnAtUtc: past.add(const Duration(days: 1)),
          ),
          past,
          now: now,
        ),
        isTrue,
      );
    });
  });
}
