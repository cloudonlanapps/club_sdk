import 'dart:convert';

import 'package:meta/meta.dart';

/// How a departing member's programme-bound credit is settled (#14).
///
/// Required by `removeEnrollment` and `approveWithdraw` when the member
/// holds a balance bound to that programme (422 `CREDIT_DISPOSITION_REQUIRED`
/// otherwise). [penalty] credits are forfeited — one figure for the
/// departure, taken oldest-account-first — and whatever survives moves into
/// a new general account valid from [validFromUtc] to [validUntilUtc].
/// A penalty of zero is ordinary. Sending a disposition where the credit
/// system is off, or for a camp or one-off, is 422
/// `CREDIT_DISPOSITION_NOT_APPLICABLE`.
@immutable
class CreditDisposition {
  const CreditDisposition({
    required this.penalty,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.reason,
  });

  factory CreditDisposition.fromMap(Map<String, dynamic> map) {
    return CreditDisposition(
      penalty: map['penalty'] as int,
      validFromUtc: DateTime.fromMillisecondsSinceEpoch(
        map['validFromUtc'] as int,
        isUtc: true,
      ),
      validUntilUtc: DateTime.fromMillisecondsSinceEpoch(
        map['validUntilUtc'] as int,
        isUtc: true,
      ),
      reason: map['reason'] as String,
    );
  }

  factory CreditDisposition.fromJson(String source) =>
      CreditDisposition.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Credits forfeited on departure; may be zero.
  final int penalty;

  /// Validity window of the general account the remainder moves into.
  final DateTime validFromUtc;
  final DateTime validUntilUtc;

  /// Mandatory: every movement of credit states why.
  final String reason;

  CreditDisposition copyWith({
    int? penalty,
    DateTime? validFromUtc,
    DateTime? validUntilUtc,
    String? reason,
  }) {
    return CreditDisposition(
      penalty: penalty ?? this.penalty,
      validFromUtc: validFromUtc ?? this.validFromUtc,
      validUntilUtc: validUntilUtc ?? this.validUntilUtc,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'penalty': penalty,
      'validFromUtc': validFromUtc.millisecondsSinceEpoch,
      'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'CreditDisposition(penalty: $penalty, validFromUtc: $validFromUtc, '
      'validUntilUtc: $validUntilUtc, reason: $reason)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditDisposition &&
        other.penalty == penalty &&
        other.validFromUtc == validFromUtc &&
        other.validUntilUtc == validUntilUtc &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(penalty, validFromUtc, validUntilUtc, reason);
}
