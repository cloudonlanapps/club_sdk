import 'package:meta/meta.dart';

import 'sdk/interfaces/admin.dart';
import 'sdk/interfaces/attendance.dart';
import 'sdk/interfaces/audit_log.dart';
import 'sdk/interfaces/auth.dart';
import 'sdk/interfaces/broadcast.dart';
import 'sdk/interfaces/capabilities.dart';
import 'sdk/interfaces/credit.dart';
import 'sdk/interfaces/enrollment.dart';
import 'sdk/interfaces/evaluation.dart';
import 'sdk/interfaces/event.dart';
import 'sdk/interfaces/event_marketing.dart';
import 'sdk/interfaces/group.dart';
import 'sdk/interfaces/inquiry.dart';
import 'sdk/interfaces/media.dart';
import 'sdk/interfaces/my_credits.dart';
import 'sdk/interfaces/my_evaluations.dart';
import 'sdk/interfaces/my_events.dart';
import 'sdk/interfaces/my_groups.dart';
import 'sdk/interfaces/notification.dart';
import 'sdk/interfaces/occurrence.dart';
import 'sdk/interfaces/owner_media.dart';
import 'sdk/interfaces/public.dart';
import 'sdk/interfaces/user.dart';
import 'sdk/interfaces/venue.dart';

/// Main entry point for the Club SDK V2 (authenticated operations).
///
/// Provides access to all SDK functionality through typed source interfaces.
/// Each source handles a specific domain of operations.
///
/// This client requires authentication for most operations and is intended
/// for use within the mobile app or admin dashboard.
///
/// Example usage:
/// ```dart
/// final client = await createSecureClient();
///
/// // Authentication
/// final token = await client.auth.login('user', 'pass');
///
/// // Events
/// final events = await client.events.listEvents(
///   filter: EventFilter.myEvents,
///   userId: 'user-id',
/// );
///
/// // Enrollments
/// await client.enrollments.invite(eventId, 'user-id');
/// ```
@immutable
class SecureClient {
  /// Creates a new SecureClient with all required source implementations.
  const SecureClient({
    required this.admin,
    required this.auth,
    required this.users,
    required this.groups,
    required this.venues,
    required this.events,
    required this.eventMarketing,
    required this.occurrences,
    required this.enrollments,
    required this.attendance,
    required this.myEvents,
    required this.myGroups,
    required this.notifications,
    required this.broadcasts,
    required this.capabilities,
    required this.credits,
    required this.myCredits,
    required this.auditLog,
    required this.media,
    required this.userMedia,
    required this.eventMedia,
    required this.groupMedia,
    required this.venueMedia,
    required this.evaluations,
    required this.myEvaluations,
    required this.evaluationMedia,
    required this.inquiries,
    required this.public,
  });

  /// Authentication operations (login, logout, register).
  /// System preferences (super-admin).
  final AdminSource admin;

  final AuthSource auth;

  /// User management operations (CRUD, roles, status).
  final UserSource users;

  /// Group management operations.
  final GroupSource groups;

  /// Venue management operations.
  final VenueSource venues;

  /// Event management operations (create, update, list, public listings).
  final EventSource events;

  /// An event's extended marketing block (`/v1/events/by_id/{id}/marketing`);
  /// a 503 `ModuleDisabledException` where the Event Marketing module is
  /// off — check [capabilities] first.
  final EventMarketingSource eventMarketing;

  /// Occurrence management operations (reschedule, cancel, list).
  final OccurrenceSource occurrences;

  /// Enrollment management operations (invite, assign, withdraw).
  final EnrollmentSource enrollments;

  /// Attendance management operations (mark, leave requests).
  final AttendanceSource attendance;

  /// Member-facing event operations (my events, enrollments, leave).
  final MyEventsSource myEvents;

  /// Member-facing groups operations (my groups, eligible groups,
  /// submit / list / cancel own join requests).
  final MyGroupsSource myGroups;

  /// Pending action counts for users.

  /// Notification operations.
  final NotificationSource notifications;

  /// Admin-only broadcast operations.
  final BroadcastSource broadcasts;

  /// Deployment capability discovery (`/capabilities`): which optional
  /// modules this server runs.
  final CapabilitiesSource capabilities;

  /// Staff-side credit operations (`/credits`): accounts, ledger, roster.
  /// Throws `ModuleDisabledException` where `capabilities.creditSystem`
  /// is false.
  final CreditSource credits;

  /// A member's own credit (`/mycredits`), also readable by staff on their
  /// behalf. Same module gate as [credits].
  final MyCreditsSource myCredits;

  /// Read-only audit-log operations (`/v1/audit_log`): global feed for
  /// super-admins, entity-scoped history for admins / coaches.
  final AuditLogSource auditLog;

  /// v2 media operations against `/v1/media`.
  final MediaSource media;

  /// Per-user media link operations (`/v1/users/by_id/{username}/media`).
  final UserMediaSource userMedia;

  /// Per-event media link operations (`/v1/events/by_id/{id}/media`).
  final EventMediaSource eventMedia;

  /// Per-group media link operations (`/v1/groups/by_id/{id}/media`).
  final GroupMediaSource groupMedia;

  /// Per-venue media link operations (`/v1/venues/by_id/{id}/media`).
  final VenueMediaSource venueMedia;

  /// Staff-side evaluation operations (`/v1/evaluations`). Optional
  /// module: check `capabilities` first; off, every call throws
  /// `ModuleDisabledException`.
  final EvaluationSource evaluations;

  /// Member-facing evaluation reads (`/v1/myevaluations`): published
  /// evaluations only, with no coach note.
  final MyEvaluationsSource myEvaluations;

  /// Per-evaluation media link operations
  /// (`/v1/evaluations/by_id/{id}/media`).
  final EvaluationMediaSource evaluationMedia;

  /// The admin inquiry inbox (`/v1/admin/inquiries`): what the public
  /// contact and interest forms submitted.
  final InquirySource inquiries;

  /// Unauthenticated public operations (`/v1/public`): staff profiles, the
  /// event catalogue, public venues, public marketing blocks, the club
  /// info document and the inquiry form.
  final PublicSource public;
}
