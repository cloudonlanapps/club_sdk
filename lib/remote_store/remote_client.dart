import '../client.dart';
import '../sdk/interfaces/public.dart';
import 'remote_store.dart';
import 'sources/admin_source.dart';
import 'sources/attendance_source.dart';
import 'sources/audit_log_source.dart';
import 'sources/auth_source.dart';
import 'sources/broadcast_source.dart';
import 'sources/capabilities_source.dart';
import 'sources/credit_source.dart';
import 'sources/enrollment_source.dart';
import 'sources/evaluation_media_source.dart';
import 'sources/evaluation_source.dart';
import 'sources/event_marketing_source.dart';
import 'sources/event_source.dart';
import 'sources/group_source.dart';
import 'sources/inquiry_source.dart';
import 'sources/media_source.dart';
import 'sources/my_credits_source.dart';
import 'sources/my_evaluations_source.dart';
import 'sources/my_events_source.dart';
import 'sources/my_groups_source.dart';
import 'sources/notification_source.dart';
import 'sources/occurrence_source.dart';
import 'sources/owner_media_source.dart';
import 'sources/public_source.dart';
import 'sources/user_source.dart';
import 'sources/venue_source.dart';

/// Creates a [SecureClient] that communicates with a remote API server.
///
/// The [baseUrl] should be the API base URL without trailing slash,
/// e.g., 'https://api.myexampleclub.com/v1'.
///
/// An optional [authToken] can be provided to pre-authenticate the client.
/// This is useful when restoring a session from saved credentials.
///
/// An optional [store] can be provided to reuse an existing HTTP client.
///
/// Example usage:
/// ```dart
/// final client = await createRemoteSecureClient(
///   baseUrl: 'https://api.myexampleclub.com/v1',
/// );
///
/// // Login
/// final token = await client.auth.login('user', 'password');
///
/// // Now authenticated - use other operations
/// final events = await client.events.listEvents();
/// ```
Future<SecureClient> createRemoteSecureClient({
  required String baseUrl,
  String? authToken,
  RemoteStore? store,
}) async {
  final effectiveStore = store ?? RemoteStore(baseUrl: baseUrl);
  if (authToken != null) {
    effectiveStore.authToken = authToken;
  }

  return SecureClient(
    admin: RemoteAdminSource(effectiveStore),
    auth: RemoteAuthSource(effectiveStore),
    users: RemoteUserSource(effectiveStore),
    groups: RemoteGroupSource(effectiveStore),
    venues: RemoteVenueSource(effectiveStore),
    events: RemoteEventSource(effectiveStore),
    eventMarketing: RemoteEventMarketingSource(effectiveStore),
    occurrences: RemoteOccurrenceSource(effectiveStore),
    enrollments: RemoteEnrollmentSource(effectiveStore),
    attendance: RemoteAttendanceSource(effectiveStore),
    myEvents: RemoteMyEventsSource(effectiveStore),
    myGroups: RemoteMyGroupsSource(effectiveStore),
    notifications: RemoteNotificationSource(effectiveStore),
    broadcasts: RemoteBroadcastSource(effectiveStore),
    capabilities: RemoteCapabilitiesSource(effectiveStore),
    credits: RemoteCreditSource(effectiveStore),
    myCredits: RemoteMyCreditsSource(effectiveStore),
    auditLog: RemoteAuditLogSource(effectiveStore),
    media: RemoteMediaSource(effectiveStore),
    userMedia: RemoteUserMediaSource(effectiveStore),
    eventMedia: RemoteEventMediaSource(effectiveStore),
    groupMedia: RemoteGroupMediaSource(effectiveStore),
    venueMedia: RemoteVenueMediaSource(effectiveStore),
    evaluations: RemoteEvaluationSource(effectiveStore),
    myEvaluations: RemoteMyEvaluationsSource(effectiveStore),
    evaluationMedia: RemoteEvaluationMediaSource(effectiveStore),
    inquiries: RemoteInquirySource(effectiveStore),
    public: RemotePublicSource(effectiveStore),
  );
}

/// Creates a [PublicSource] for the token-free `/public` routes, with no
/// [SecureClient] and no login (#9) — for a caller such as a public website
/// that holds no authenticated session.
///
/// [baseUrl] and [store] are as for [createRemoteSecureClient]. The store
/// carries no token unless the caller set one on a [store] they passed in;
/// nothing on `/public` needs one.
///
/// ```dart
/// final public = createRemotePublicSource(
///   baseUrl: 'https://api.myexampleclub.com/v1',
/// );
/// final info = await public.getPublicClubInfo();
/// ```
PublicSource createRemotePublicSource({
  required String baseUrl,
  RemoteStore? store,
}) => RemotePublicSource(store ?? RemoteStore(baseUrl: baseUrl));
