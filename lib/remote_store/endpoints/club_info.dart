import 'package:meta/meta.dart';

/// The unauthenticated club-info read (club_server#296, #35).
@immutable
class ClubInfoEndpoints {
  const ClubInfoEndpoints();

  String get publicClubInfo => '/public/club-info';
}
