import 'package:meta/meta.dart';

import '../models/user.dart';

class MembershipShim {
  static bool Function(UserRoles) _resolver = shimEverybodyIsMember;

  static bool isMember(UserRoles roles) => _resolver(roles);

  @visibleForTesting
  static void overrideResolver(bool Function(UserRoles)? value) {
    _resolver = value ?? shimEverybodyIsMember;
  }
}

bool shimEverybodyIsMember(UserRoles _) => true;
