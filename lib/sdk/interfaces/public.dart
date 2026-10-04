import '../models/enums.dart';
import '../models/event_marketing.dart';
import '../models/inquiry_kind.dart';
import '../models/pagination.dart';
import '../models/public_club_info.dart';
import '../models/public_event.dart';
import '../models/public_profile.dart';
import '../models/public_venue.dart';

/// Interface for unauthenticated public operations (`/public`).
///
/// These endpoints require no authentication and expose only privacy-safe
/// projections keyed by opaque public ids (an HMAC of the username, event
/// id or venue id; never the integer id), so the same surface can serve
/// both the app and a logged-out website.
abstract interface class PublicSource {
  /// List the coaches who consented to the staff page, in curated order
  /// (club_server#332, #24). Guests are withheld unless [includeGuests];
  /// hidden coaches are never returned.
  Future<List<PublicProfile>> listPublicStaff({bool includeGuests = false});

  /// Get a single public profile by its [publicId].
  ///
  /// Throws when no publicly-eligible profile matches (the server returns
  /// 404 for unknown ids and for users that aren't surfaced coaches).
  Future<PublicProfile> getPublicProfile(String publicId);

  /// The event catalogue (club_server#299, #22): public, live events,
  /// paginated, newest-starting last. Filters: [type]; [featured];
  /// [venueId], a venue's **public** id; a window where [from] keeps
  /// events with an occurrence ending at or after it and [to] keeps
  /// events starting at or before it. [limit] is 1–100, default 20.
  Future<PaginatedList<PublicEvent>> listPublicEvents({
    EventType? type,
    DateTime? from,
    DateTime? to,
    bool? featured,
    String? venueId,
    int? offset,
    int? limit,
  });

  /// One public, live event by its [publicId]. A private or deleted event,
  /// an integer id or an unknown id is a 404 `ServerException`.
  Future<PublicEvent> getPublicEvent(String publicId);

  /// The extended marketing block of a public, live event by its
  /// [publicId] (club_server#410, #22). 404 for a private or deleted
  /// event, an event without a block, or an unknown id; 503
  /// `ModuleDisabledException` where the module is off.
  Future<EventMarketing> getPublicEventMarketing(String publicId);

  /// The extended marketing blocks of up to 50 public events at once, for
  /// listing cards, keyed by public id. Unknown and private ids are
  /// silently absent; an empty list returns `{}` without a request; more
  /// than 50 is a 422 `TOO_MANY_IDS`; 503
  /// `ModuleDisabledException` where the module is off.
  Future<Map<String, EventMarketing>> listPublicEventMarketing(
    List<String> publicIds,
  );

  /// Every live venue as its public projection (club_server#307, #22).
  Future<List<PublicVenue>> listPublicVenues();

  /// One live venue by its [publicId]; a deleted, integer or unknown id is
  /// a 404 `ServerException`.
  Future<PublicVenue> getPublicVenue(String publicId);

  /// The club's public identity and the website's media slots
  /// (club_server#296, #35). Both maps are empty, never null, on a
  /// deployment that has set nothing.
  Future<PublicClubInfo> getPublicClubInfo();

  /// A fill-time token for the public inquiry form (club_server#407, #35).
  ///
  /// Fetch it when the form is rendered and send it back with the
  /// submission: the server drops anything returned in under three
  /// seconds, on the reasoning that no human fills a form that fast.
  Future<String> getInquiryFormToken();

  /// Submits a contact or interest inquiry.
  ///
  /// [token] is the value [getInquiryFormToken] returned. [website] is the
  /// honeypot: leave it null from an app, and bind it to a hidden field on
  /// a web form so a bot that fills everything gives itself away. [extra]
  /// carries whatever else the form asked.
  ///
  /// The server always answers 202 with no body, whether it kept the
  /// submission or dropped it, so a caller learns nothing about the spam
  /// rules — this returns normally in both cases.
  Future<void> submitInquiry({
    required InquiryKind kind,
    required String name,
    required String email,
    required String message,
    required String token,
    String? phone,
    Map<String, dynamic>? extra,
    String? website,
  });
}
