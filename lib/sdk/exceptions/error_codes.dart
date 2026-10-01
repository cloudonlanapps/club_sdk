/// All known error codes used by the server and SDK.
///
/// Server error codes are sent as the `code` field in HTTP error responses.
/// Client-side codes are used by `SdkError` for local validation errors.
abstract final class SdkErrorCode {
  // ═══════════════════════════════════════════════════════════════════════════
  // 400 Bad Request
  // ═══════════════════════════════════════════════════════════════════════════
  static const validationError = 'VALIDATION_ERROR';
  // A date of birth that is not 00:00:00 UTC, on registration, profile
  // update and reapply (club_server#506). Sent with status 422.
  static const invalidDobNotUtcMidnight = 'INVALID_DOB_NOT_UTC_MIDNIGHT';
  // Series reschedule on a programme (use the /future split). The conflict
  // endpoints accept every type and no longer send this (#16).
  static const eventTypeNotSupported = 'EVENT_TYPE_NOT_SUPPORTED';
  static const invalidSessionsTotal = 'INVALID_SESSIONS_TOTAL';
  static const invalidSessionsEmpty = 'INVALID_SESSIONS_EMPTY';
  // Event series cancel — camp effective-time validations (#108).
  static const effectiveTimeNotSessionBoundary =
      'EFFECTIVE_TIME_NOT_SESSION_BOUNDARY';
  static const effectiveTimeInPast = 'EFFECTIVE_TIME_IN_PAST';
  static const cancellationLeadTimeViolated = 'CANCELLATION_LEAD_TIME_VIOLATED';
  // Reschedule lead time, every type (#16). Moving an occurrence earlier is
  // 422 POSTPONE_ONLY (below).
  static const rescheduleLeadTimeViolated = 'RESCHEDULE_LEAD_TIME_VIOLATED';
  // Event series undo-cancel (#111).
  static const eventNotCancelled = 'EVENT_NOT_CANCELLED';
  static const invalidDatetime = 'INVALID_DATETIME';
  static const invalidRrule = 'INVALID_RRULE';
  static const cannotTransferToSelf = 'CANNOT_TRANSFER_TO_SELF';
  static const fileTooLarge = 'FILE_TOO_LARGE';
  static const invalidMediaType = 'INVALID_MEDIA_TYPE';
  static const passwordChangeFailed = 'PASSWORD_CHANGE_FAILED';
  static const rangeTooLarge = 'RANGE_TOO_LARGE';
  static const venueHasEvents = 'VENUE_HAS_EVENTS';
  static const venueHasFutureEvents = 'VENUE_HAS_FUTURE_EVENTS';
  static const defaultVenueExists = 'DEFAULT_VENUE_EXISTS';

  // ═══════════════════════════════════════════════════════════════════════════
  // 401 Unauthorized
  // ═══════════════════════════════════════════════════════════════════════════
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const notAuthenticated = 'NOT_AUTHENTICATED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const accountBlocked = 'ACCOUNT_BLOCKED';
  static const accountPending = 'ACCOUNT_PENDING';
  // An access token that fails to decode, or whose session was revoked by
  // logout (club_server#510). Refreshing may help only in the first case.
  static const invalidToken = 'INVALID_TOKEN';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  // A signed-in member who has left the club (status `left`).
  static const accountLeft = 'ACCOUNT_LEFT';

  // ═══════════════════════════════════════════════════════════════════════════
  // 403 Forbidden
  // ═══════════════════════════════════════════════════════════════════════════
  static const insufficientPermission = 'INSUFFICIENT_PERMISSION';
  static const superAdminProtection = 'SUPER_ADMIN_PROTECTION';

  // ═══════════════════════════════════════════════════════════════════════════
  // 404 Not Found
  // ═══════════════════════════════════════════════════════════════════════════
  static const userNotFound = 'USER_NOT_FOUND';
  static const eventNotFound = 'EVENT_NOT_FOUND';
  static const venueNotFound = 'VENUE_NOT_FOUND';
  static const groupNotFound = 'GROUP_NOT_FOUND';
  static const enrollmentNotFound = 'ENROLLMENT_NOT_FOUND';
  static const occurrenceNotFound = 'OCCURRENCE_NOT_FOUND';
  // `PATCH …/correction` named a `scheduleId` that is not one of this
  // event's schedules (club_server#423, #3).
  static const scheduleNotFound = 'SCHEDULE_NOT_FOUND';
  static const notificationNotFound = 'NOTIFICATION_NOT_FOUND';
  // A direct notification to a user who may not receive it: one who has left,
  // or a blocked user for anything but an account notice (club_server#511,
  // #512). Sent with status 422.
  static const recipientNotDeliverable = 'RECIPIENT_NOT_DELIVERABLE';
  static const linkNotFound = 'LINK_NOT_FOUND';
  static const attendanceNotFound = 'ATTENDANCE_NOT_FOUND';
  static const fileNotFound = 'FILE_NOT_FOUND';
  static const uploadNotFound = 'UPLOAD_NOT_FOUND';
  static const memberNotFound = 'MEMBER_NOT_FOUND';
  static const roleNotFound = 'ROLE_NOT_FOUND';
  static const galleryItemNotFound = 'GALLERY_ITEM_NOT_FOUND';
  // Credit system (#14): no account with that 8-character code.
  static const creditAccountNotFound = 'CREDIT_ACCOUNT_NOT_FOUND';
  // Evaluations (club_server#302): unknown evaluation or template id. An
  // evaluation the caller does not own is not found either (#535).
  static const evaluationNotFound = 'EVALUATION_NOT_FOUND';
  static const templateNotFound = 'TEMPLATE_NOT_FOUND';
  // An item named through a template it does not belong to, or an unknown
  // copy origin (club_server#535).
  static const itemNotFound = 'ITEM_NOT_FOUND';
  // The event has no extended marketing block (club_server#410, #22).
  static const eventMarketingNotFound = 'EVENT_MARKETING_NOT_FOUND';

  // The batch public marketing read was given more than 50 public ids
  // (club_server#410, #22).
  static const tooManyIds = 'TOO_MANY_IDS';

  // ═══════════════════════════════════════════════════════════════════════════
  // 409 Conflict
  // ═══════════════════════════════════════════════════════════════════════════
  static const duplicateUsername = 'DUPLICATE_USERNAME';
  static const duplicateEmail = 'DUPLICATE_EMAIL';
  static const alreadyEnrolled = 'ALREADY_ENROLLED';
  static const alreadyMember = 'ALREADY_MEMBER';
  static const roleAlreadyAssigned = 'ROLE_ALREADY_ASSIGNED';
  static const leaveAlreadyDeclared = 'LEAVE_ALREADY_DECLARED';
  static const conflict = 'CONFLICT';
  // Also inferred for a 409 whose body is a conflict report (`hasConflict`)
  // with no code: a blocking programme clash (#16). The report is in
  // `ServerException.details`.
  static const timeConflict = 'TIME_CONFLICT';
  // Optimistic locking: the `version` sent is not the current one — of the
  // event for an update, correction, split or reschedule (club_server#292,
  // #434; SDK #25, #5), or of the occurrence for an occurrence change, drop
  // or reinstate (club_server#430, #1). Mapped to `StaleVersionException`,
  // which carries the current version and writer.
  static const staleVersion = 'STALE_VERSION';
  // Event reschedule refused: per-occurrence overrides exist. The offending
  // slots are in `ServerException.details['occurrenceTimeUtcs']`. Retry with
  // `resetOverrides: true` to clear them (#230).
  static const occurrenceOverridesPresent = 'OCCURRENCE_OVERRIDES_PRESENT';
  static const galleryItemExists = 'GALLERY_ITEM_EXISTS';
  // v2 media link tables (#162): duplicate (tag, mediaUuid) attach.
  static const mediaLinkExists = 'MEDIA_LINK_EXISTS';

  // v2 media (#161): delete conflicts.
  // `MEDIA_IN_USE`: soft-delete refused because links still reference the
  // media. The full link list is in `ServerException.details['links']`.
  static const mediaInUse = 'MEDIA_IN_USE';

  // ═══════════════════════════════════════════════════════════════════════════
  // 422 Unprocessable Entity
  // ═══════════════════════════════════════════════════════════════════════════
  static const invalidState = 'INVALID_STATE';
  // Hard delete of an item that was not soft-deleted first — group, user,
  // template, evaluation, media item or event (club_server#526). Replaces
  // `MEDIA_NOT_DELETED` and the per-endpoint `NOT_DELETED` / `INVALID_STATE`.
  static const hardDeleteNeedsSoftDelete = 'HARD_DELETE_NEEDS_SOFT_DELETE';
  // Restore of an item that is not deleted — event, user, venue, group,
  // template or media item (club_server#526, #520). Replaces `NOT_DELETED`.
  static const nothingToRestore = 'NOTHING_TO_RESTORE';
  // Upload of an image or PDF the converter rejects (club_server#521): no
  // media item is created. Not the download-time `CONVERSION_FAILED`.
  static const mediaConversionFailed = 'MEDIA_CONVERSION_FAILED';
  // Adding, changing or removing a media link on a soft-deleted group, venue
  // or event (club_server#517): its links are read-only.
  static const ownerDeleted = 'OWNER_DELETED';
  // Single-occurrence reschedule with an all-null body (#113). The event-level
  // /reschedule rejects an empty body at the schema layer (VALIDATION_ERROR).
  static const nothingToReschedule = 'NOTHING_TO_RESCHEDULE';
  // Event /reschedule attempted after the series has started (#230).
  static const eventAlreadyStarted = 'EVENT_ALREADY_STARTED';
  // RRULE shape per type (#16): programme is `FREQ=WEEKLY;BYDAY=…` with no
  // COUNT/UNTIL/EXDATE/INTERVAL, a camp rule may not carry UNTIL, a one-off
  // has no rule at all.
  static const invalidRruleForCamp = 'INVALID_RRULE_FOR_CAMP';
  static const invalidRruleForProgramme = 'INVALID_RRULE_FOR_PROGRAMME';
  static const invalidRruleForOneoff = 'INVALID_RRULE_FOR_ONEOFF';
  // An occurrence may only be postponed, never moved earlier (#16).
  static const postponeOnly = 'POSTPONE_ONLY';
  // Split / terminate cutoff less than 30 minutes ahead (#16).
  static const cutoffTooSoon = 'CUTOFF_TOO_SOON';
  // A camp or one-off more than 52 weeks out (#16).
  static const beyondSchedulingHorizon = 'BEYOND_SCHEDULING_HORIZON';
  // Per-occurrence sessions that do not fit the window (#16).
  static const invalidSessions = 'INVALID_SESSIONS';
  // submit-for-review requires a live identity_document media link (#142).
  static const identityDocumentRequired = 'IDENTITY_DOCUMENT_REQUIRED';
  static const galleryTagFull = 'GALLERY_TAG_FULL';
  static const galleryTooManyTags = 'GALLERY_TOO_MANY_TAGS';
  // v2 media link tables (#162).
  static const mediaLinkTagFull = 'MEDIA_LINK_TAG_FULL';
  static const mediaLinkTooManyTags = 'MEDIA_LINK_TOO_MANY_TAGS';
  static const invalidTransition = 'INVALID_TRANSITION';
  static const pastOccurrence = 'PAST_OCCURRENCE';
  static const cancelledOccurrence = 'CANCELLED_OCCURRENCE';
  static const eventAlreadyCancelled = 'EVENT_ALREADY_CANCELLED';
  static const leaveWindowClosed = 'LEAVE_WINDOW_CLOSED';
  static const editWindowClosed = 'EDIT_WINDOW_CLOSED';
  static const attendanceNotYetOpen = 'ATTENDANCE_NOT_YET_OPEN';
  static const alreadyBlocked = 'ALREADY_BLOCKED';
  static const alreadyDeleted = 'ALREADY_DELETED';
  static const alreadyLeft = 'ALREADY_LEFT';
  static const notBlocked = 'NOT_BLOCKED';
  static const notCancelled = 'NOT_CANCELLED';
  static const notLeft = 'NOT_LEFT';
  static const conversionFailed = 'CONVERSION_FAILED';
  static const conversionInProgress = 'CONVERSION_IN_PROGRESS';
  static const memberNotActive = 'MEMBER_NOT_ACTIVE';
  static const invalidAttendanceStatus = 'INVALID_ATTENDANCE_STATUS';
  static const autoGroupModificationNotAllowed =
      'AUTO_GROUP_MODIFICATION_NOT_ALLOWED';
  static const autoGroupNotJoinable = 'AUTO_GROUP_NOT_JOINABLE';
  static const membersExist = 'MEMBERS_EXIST';
  static const membersIneligible = 'MEMBERS_INELIGIBLE';
  static const notEligible = 'NOT_ELIGIBLE';
  static const userNotEligibleForEvent = 'USER_NOT_ELIGIBLE_FOR_EVENT';
  // Evaluations (club_server#302, #535). Event-scoped eligibility failures
  // (owner not on `coachNames`, member without an attendance record, an
  // owner without the coach role) are `NOT_ELIGIBLE` above; lifecycle
  // misuse is `INVALID_TRANSITION`, and editing anything but a draft is
  // `INVALID_STATE`.
  // A template deleted, or its items or layout changed, while evaluations
  // use it. The count is in `ServerException.details['details']['count']`.
  static const templateInUse = 'TEMPLATE_IN_USE';
  // An answer of the wrong kind, outside its item's domain, or for an item
  // that is not a question of the evaluation's template.
  static const invalidAnswer = 'INVALID_ANSWER';
  // Save refused: a required question is unanswered, or an answer lacks
  // the coach note it requires. The items are in
  // `ServerException.details['details']['itemIds']`.
  static const incomplete = 'INCOMPLETE';
  // A template layout that does not name every item exactly once.
  static const invalidLayout = 'INVALID_LAYOUT';
  // A replacement item of another type than the item it replaces.
  static const itemTypeFixed = 'ITEM_TYPE_FIXED';
  // A copied item whose answer domain differs from its origin's.
  static const originMismatch = 'ORIGIN_MISMATCH';
  // Evidence on an item that is not a question allowing it, or a file that
  // is not an image, a video or a PDF.
  static const invalidEvidence = 'INVALID_EVIDENCE';
  // A live template already holds the name, compared without regard to
  // case or surrounding spaces: create, rename and restore.
  static const templateNameTaken = 'TEMPLATE_NAME_TAKEN';
  // The effective owner already holds a live review of this member and
  // template over the same period (the exact bounds, or none): create, a
  // draft's event or period change, transfer and restore.
  static const duplicateEvaluation = 'DUPLICATE_EVALUATION';
  // A review period ending after the server's clock: a review looks back.
  static const periodInFuture = 'PERIOD_IN_FUTURE';

  // Credit system (#14, club_server#294).
  // Opening an account against a camp or one-off: credit is for programmes.
  static const creditNotApplicable = 'CREDIT_NOT_APPLICABLE';
  // The opening amount is not a positive whole number.
  static const invalidCreditAmount = 'INVALID_CREDIT_AMOUNT';
  // A validity window ending before it starts, or wholly in the past.
  static const invalidValidityWindow = 'INVALID_VALIDITY_WINDOW';
  // No usable credit for the programme: assign, trial-assign, approve,
  // request and accept refuse with it; a bulk attendance mark reports it
  // per member in `AttendanceMarkReport.refused` instead of throwing.
  static const insufficientCredit = 'INSUFFICIENT_CREDIT';
  // A reversal larger than what remains unspent on the account.
  static const insufficientBalance = 'INSUFFICIENT_BALANCE';
  // Extend, reverse or transfer on an account a transfer already closed.
  static const accountClosed = 'ACCOUNT_CLOSED';
  // removeEnrollment / approveWithdraw on a member holding a balance bound
  // to the programme, with no `CreditDisposition`. The member stays.
  static const creditDispositionRequired = 'CREDIT_DISPOSITION_REQUIRED';
  // A `CreditDisposition` sent where the credit system is off, or for a
  // camp or one-off.
  static const creditDispositionNotApplicable =
      'CREDIT_DISPOSITION_NOT_APPLICABLE';
  // Opening a credit account for the super admin, a housekeeping account
  // that never holds credit (club_server#519).
  static const superAdminCannotHoldCredit = 'SUPER_ADMIN_CANNOT_HOLD_CREDIT';

  // ═══════════════════════════════════════════════════════════════════════════
  // 503 Service Unavailable — optional module off on this deployment.
  // Every route of a module stays registered; where the module is off it
  // answers 503 with one of these, mapped to `ModuleDisabledException`.
  // Discover the modules with `GET /capabilities` instead of probing.
  // ═══════════════════════════════════════════════════════════════════════════
  static const creditSystemDisabled = 'CREDIT_SYSTEM_DISABLED';
  static const evaluationsDisabled = 'EVALUATIONS_DISABLED';
  static const eventMarketingDisabled = 'EVENT_MARKETING_DISABLED';

  // Media encryption has no key configured on this deployment.
  static const encryptionNotConfigured = 'ENCRYPTION_NOT_CONFIGURED';

  /// The codes that mean "module off", for `ModuleDisabledException`.
  static const Set<String> moduleDisabledCodes = {
    creditSystemDisabled,
    evaluationsDisabled,
    eventMarketingDisabled,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // Client-side SDK codes (used with SdkError)
  // ═══════════════════════════════════════════════════════════════════════════
  static const rruleNotAllowed = 'RRULE_NOT_ALLOWED';
  // A 2xx response whose body is not the JSON shape the call expects (a
  // proxy's HTML page, a list where a map was expected). The server answered,
  // so this is not an outage.
  static const invalidResponse = 'INVALID_RESPONSE';
  static const rruleConstraintViolation = 'RRULE_CONSTRAINT_VIOLATION';
  static const invalidEventType = 'INVALID_EVENT_TYPE';
}
