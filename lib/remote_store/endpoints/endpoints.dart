import 'package:meta/meta.dart';

import 'admin.dart';
import 'attendance.dart';
import 'audit_log.dart';
import 'auth.dart';
import 'broadcast.dart';
import 'capabilities.dart';
import 'club_info.dart';
import 'credit.dart';
import 'enrollment.dart';
import 'evaluation.dart';
import 'event.dart';
import 'event_marketing.dart';
import 'group.dart';
import 'inquiry.dart';
import 'media.dart';
import 'my_evaluations.dart';
import 'my_events.dart';
import 'my_groups.dart';
import 'notification.dart';
import 'occurrence.dart';
import 'public.dart';
import 'user.dart';
import 'venue.dart';

@immutable
class Endpoints {
  const Endpoints();

  AdminEndpoints get admin => const AdminEndpoints();
  AuthEndpoints get auth => const AuthEndpoints();
  UserEndpoints get users => const UserEndpoints();
  EventEndpoints get events => const EventEndpoints();
  EventMarketingEndpoints get eventMarketing => const EventMarketingEndpoints();
  ClubInfoEndpoints get clubInfo => const ClubInfoEndpoints();
  InquiryEndpoints get inquiries => const InquiryEndpoints();
  OccurrenceEndpoints get occurrences => const OccurrenceEndpoints();
  AttendanceEndpoints get attendance => const AttendanceEndpoints();
  EnrollmentEndpoints get enrollments => const EnrollmentEndpoints();
  MyEventsEndpoints get myEvents => const MyEventsEndpoints();
  MyGroupsEndpoints get myGroups => const MyGroupsEndpoints();
  EvaluationEndpoints get evaluations => const EvaluationEndpoints();
  MyEvaluationsEndpoints get myEvaluations => const MyEvaluationsEndpoints();
  VenueEndpoints get venues => const VenueEndpoints();
  GroupEndpoints get groups => const GroupEndpoints();
  NotificationEndpoints get notifications => const NotificationEndpoints();
  BroadcastEndpoints get broadcasts => const BroadcastEndpoints();
  CapabilitiesEndpoints get capabilities => const CapabilitiesEndpoints();
  CreditEndpoints get credits => const CreditEndpoints();
  AuditLogEndpoints get auditLog => const AuditLogEndpoints();
  MediaEndpoints get media => const MediaEndpoints();
  OwnerMediaEndpoints get ownerMedia => const OwnerMediaEndpoints();
  PublicEndpoints get public => const PublicEndpoints();
}

const endpoints = Endpoints();
