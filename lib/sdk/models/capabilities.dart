import 'dart:convert';

import 'package:meta/meta.dart';

/// What this deployment can do (`GET /capabilities`, club_server#339): the
/// optional modules, and whether registration needs identity verification.
///
/// The optional modules are switched per deployment and every one of their
/// routes stays registered, answering 503 where the module is off, so the
/// published OpenAPI schema does not vary with configuration. Read this
/// once after login to decide which features to show; a call into a
/// disabled module surfaces as `ModuleDisabledException`.
@immutable
class Capabilities {
  const Capabilities({
    this.creditSystem = false,
    this.evaluations = false,
    this.eventMarketing = false,
    this.identityVerification = true,
  });

  factory Capabilities.fromMap(Map<String, dynamic> map) {
    return Capabilities(
      creditSystem: (map['creditSystem'] as bool?) ?? false,
      evaluations: (map['evaluations'] as bool?) ?? false,
      eventMarketing: (map['eventMarketing'] as bool?) ?? false,
      identityVerification: (map['identityVerification'] as bool?) ?? true,
    );
  }

  factory Capabilities.fromJson(String source) =>
      Capabilities.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The credit system (club_server#294).
  final bool creditSystem;

  /// Evaluations (club_server#302).
  final bool evaluations;

  /// Extended event marketing (club_server#410).
  final bool eventMarketing;

  /// Whether a registrant must upload an identity document and submit for
  /// review before an admin can approve them (club_server#428, #2).
  ///
  /// When false, `register` returns the user already `pending` and admins
  /// are notified at once; skip the document and submit-for-review steps.
  /// **Absent means true**, unlike the module flags: a server that predates
  /// the field always required verification.
  final bool identityVerification;

  Capabilities copyWith({
    bool? creditSystem,
    bool? evaluations,
    bool? eventMarketing,
    bool? identityVerification,
  }) {
    return Capabilities(
      creditSystem: creditSystem ?? this.creditSystem,
      evaluations: evaluations ?? this.evaluations,
      eventMarketing: eventMarketing ?? this.eventMarketing,
      identityVerification: identityVerification ?? this.identityVerification,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creditSystem': creditSystem,
      'evaluations': evaluations,
      'eventMarketing': eventMarketing,
      'identityVerification': identityVerification,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'Capabilities(creditSystem: $creditSystem, evaluations: $evaluations, '
      'eventMarketing: $eventMarketing, '
      'identityVerification: $identityVerification)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Capabilities &&
        other.creditSystem == creditSystem &&
        other.evaluations == evaluations &&
        other.eventMarketing == eventMarketing &&
        other.identityVerification == identityVerification;
  }

  @override
  int get hashCode =>
      creditSystem.hashCode ^
      evaluations.hashCode ^
      eventMarketing.hashCode ^
      identityVerification.hashCode;
}
