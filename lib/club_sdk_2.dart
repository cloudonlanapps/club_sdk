// ═════════════════════════════════════════════════════════════════════════════
// CLIENT
// ═════════════════════════════════════════════════════════════════════════════

export 'client.dart' show SecureClient;
// ═════════════════════════════════════════════════════════════════════════════
// EXCEPTIONS
// ═════════════════════════════════════════════════════════════════════════════

export 'sdk/exceptions/error_codes.dart' show SdkErrorCode;
export 'sdk/exceptions/exceptions.dart'
    show
        ModuleDisabledException,
        SdkError,
        SdkException,
        ServerException,
        StaleVersionException;
// ═════════════════════════════════════════════════════════════════════════════
// INTERFACES
// ═════════════════════════════════════════════════════════════════════════════

export 'sdk/interfaces/audit_log.dart' show AuditLogSource;
export 'sdk/interfaces/capabilities.dart' show CapabilitiesSource;
export 'sdk/interfaces/credit.dart' show CreditSource;
export 'sdk/interfaces/evaluation.dart' show EvaluationSource;
export 'sdk/interfaces/event_marketing.dart' show EventMarketingSource;
export 'sdk/interfaces/inquiry.dart' show InquirySource;
export 'sdk/interfaces/media.dart' show MediaSource;
export 'sdk/interfaces/my_credits.dart' show MyCreditsSource;
export 'sdk/interfaces/my_evaluations.dart' show MyEvaluationsSource;
export 'sdk/interfaces/my_events.dart' show MyEventsSource;
export 'sdk/interfaces/my_groups.dart' show MyGroupsSource;
export 'sdk/interfaces/owner_media.dart'
    show
        EvaluationMediaSource,
        EventMediaSource,
        GroupMediaSource,
        OwnerMediaSource,
        UserMediaSource,
        VenueMediaSource;
export 'sdk/interfaces/public.dart' show PublicSource;
// ═════════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════════

// ClubInfo is exported from the_club/club_info.dart below
export 'sdk/models/address.dart' show Address;
export 'sdk/models/attendance.dart' show AttendanceRecord, AttendanceStats;
export 'sdk/models/attendance_mark_record.dart' show AttendanceMarkRecord;
export 'sdk/models/attendance_mark_report.dart' show AttendanceMarkReport;
export 'sdk/models/audit_log.dart' show AuditLogPage, AuditLogRow, AuditUserRef;
export 'sdk/models/auth_token.dart' show AuthToken;
export 'sdk/models/broadcast.dart'
    show
        AudienceKind,
        AudienceSelector,
        Broadcast,
        BroadcastRecipient,
        BroadcastStatus;
export 'sdk/models/bulk_members_result.dart' show BulkMembersResult;
export 'sdk/models/capabilities.dart' show Capabilities;
export 'sdk/models/club_membership.dart' show ClubMembership;
export 'sdk/models/conflict_report.dart'
    show ConflictReport, EventConflictItem, OccurrencePair;
export 'sdk/models/contact_info.dart'
    show
        ContactFormLabels,
        ContactInfoLabels,
        ContactMapLabels,
        ContactPageLabels,
        ContactSubjectOptions;
export 'sdk/models/credit_account.dart' show CreditAccount;
export 'sdk/models/credit_account_kind.dart' show CreditAccountKind;
export 'sdk/models/credit_account_state.dart' show CreditAccountState;
export 'sdk/models/credit_disposition.dart' show CreditDisposition;
export 'sdk/models/credit_entry.dart' show CreditEntry;
export 'sdk/models/credit_entry_type.dart' show CreditEntryType;
export 'sdk/models/credit_transfer_result.dart' show CreditTransferResult;
export 'sdk/models/eligible_user.dart' show EligibleUser;
export 'sdk/models/enrollment.dart' show Enrollment;
export 'sdk/models/enums.dart'
    show
        AttendanceStatus,
        EnrollmentStatus,
        EventLifecycleState,
        EventStatus,
        EventType,
        OccurrenceStatus,
        Visibility;
export 'sdk/models/evaluation_category.dart' show EvaluationCategory;
export 'sdk/models/evaluation_member_view.dart' show EvaluationMemberView;
export 'sdk/models/evaluation_scope.dart' show EvaluationScope;
export 'sdk/models/evaluation_scope_type.dart' show EvaluationScopeType;
export 'sdk/models/evaluation_score.dart' show EvaluationScore;
export 'sdk/models/evaluation_score_input.dart' show EvaluationScoreInput;
export 'sdk/models/evaluation_staff_view.dart' show EvaluationStaffView;
export 'sdk/models/evaluation_status.dart' show EvaluationStatus;
export 'sdk/models/evaluation_template.dart' show EvaluationTemplate;
export 'sdk/models/event.dart' show Event;
export 'sdk/models/event_detail_gallery_labels.dart'
    show EventDetailGalleryLabels;
export 'sdk/models/event_input.dart' show EventInput;
export 'sdk/models/event_marketing.dart' show EventMarketing;
export 'sdk/models/event_marketing_basic.dart' show EventMarketingBasic;
export 'sdk/models/event_schedule.dart' show EventSchedule;
export 'sdk/models/event_session.dart' show EventSession;
export 'sdk/models/facility.dart' show Facility;
export 'sdk/models/fee_item.dart' show FeeItem;
export 'sdk/models/gender.dart' show Gender;
export 'sdk/models/group.dart' show Group;
export 'sdk/models/group_kind.dart' show GroupKind;
export 'sdk/models/group_member.dart' show GroupMember;
export 'sdk/models/inquiry.dart' show Inquiry;
export 'sdk/models/inquiry_kind.dart' show InquiryKind;
export 'sdk/models/join_request.dart' show JoinRequest, JoinRequestStatus;
export 'sdk/models/marked_attendance.dart' show MarkedAttendance;
export 'sdk/models/media.dart' show Media;
export 'sdk/models/media_link.dart'
    show
        MediaLink,
        MediaLinkCrossEntry,
        MediaLinkOwnerType,
        MediaLinkReverseEntry;
export 'sdk/models/media_link_limits.dart' show MediaLinkLimits;
export 'sdk/models/media_ref.dart' show MediaRef;
export 'sdk/models/member_credit_status.dart' show MemberCreditStatus;
export 'sdk/models/my_attendance_record.dart' show MyAttendanceRecord;
export 'sdk/models/my_attendance_stats.dart' show MyAttendanceStats;
export 'sdk/models/notification.dart'
    show
        AppNotification,
        NotificationChannel,
        NotificationChannelSupport,
        NotificationPref,
        PendingActionType;
export 'sdk/models/notification_type.dart' show NotificationType;
export 'sdk/models/occurrence.dart' show Occurrence;
export 'sdk/models/occurrence_override.dart' show OccurrenceOverride;
export 'sdk/models/package_offer.dart' show PackageOffer;
export 'sdk/models/pagination.dart' show PaginatedList;
export 'sdk/models/promotional_offer.dart' show PromotionalOffer;
export 'sdk/models/public_club_info.dart' show PublicClubInfo;
export 'sdk/models/public_event.dart' show PublicEvent;
export 'sdk/models/public_profile.dart'
    show PublicProfile, computeDisplayName, computePublicDisplayName;
export 'sdk/models/public_venue.dart' show PublicVenue;
export 'sdk/models/refused_attendance.dart' show RefusedAttendance;
export 'sdk/models/role.dart' show Role;
export 'sdk/models/rrule_config.dart' show RruleConfig;
export 'sdk/models/staff_listing_row.dart' show StaffListingRow;
export 'sdk/models/system_preference.dart' show SystemPreference;
export 'sdk/models/the_club/club_history_data.dart' show ClubHistoryData;
// Page content models
export 'sdk/models/the_club/club_info.dart' show ClubInfo;
export 'sdk/models/the_club/club_value_card_data.dart' show ClubValueCardData;
export 'sdk/models/user.dart' show UserInfo, UserPrivate, UserRoles, UserStatus;
export 'sdk/models/user_conflict_report.dart'
    show UserConflictItem, UserConflictReport;
export 'sdk/models/user_counts.dart' show UserCounts;
export 'sdk/models/user_list_filter.dart' show UserListFilter;
export 'sdk/models/user_stats.dart' show UserStats;
export 'sdk/models/venue.dart' show Venue;
// ═════════════════════════════════════════════════════════════════════════════
// UTILS
// ═════════════════════════════════════════════════════════════════════════════

export 'sdk/utils/event_action_gates.dart'
    show
        attendanceEditWindow,
        attendanceOpenLeadIn,
        canAssignTrial,
        canEnrollOnEvent,
        canManageAttendance,
        canMarkAttendanceNow,
        enrollmentCoversOccurrence,
        isEventSeriesCancelled,
        isInLeaveApplicationWindow,
        isInScheduleManagementWindow,
        isOccurrenceCancelled,
        isPastEvent,
        lastOccurrenceEndUtc,
        leaveCutoff,
        mapAttendanceMutationError,
        mapEnrollmentMutationError;
export 'sdk/utils/event_schedule_summary.dart' show eventScheduleSummary;
export 'sdk/utils/format_utils.dart' show formatDate, formatIndianNumber;
export 'sdk/utils/media_download_url.dart'
    show
        MediaDownloadUrlParts,
        mediaAnimatedUrl,
        mediaDownloadUrl,
        mediaDownloadUrlParts,
        mediaPosterUrl;
export 'sdk/utils/membership.dart' show MembershipShim;
export 'sdk/utils/rrule_translator.dart'
    show getDayName, translateDay, translateRRule;
export 'sdk/utils/rrule_util.dart' show RruleExpansionResult, RruleUtil;
