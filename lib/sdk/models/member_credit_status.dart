import 'dart:convert';

import 'package:meta/meta.dart';

/// One row of a programme's credit roster (#14): whether an enrolled
/// member can be marked, and which account would pay.
@immutable
class MemberCreditStatus {
  const MemberCreditStatus({
    required this.membername,
    required this.usableCredits,
    required this.blocked,
    this.payingAccountId,
    this.nextExpiryUtc,
  });

  factory MemberCreditStatus.fromMap(Map<String, dynamic> map) {
    return MemberCreditStatus(
      membername: map['membername'] as String,
      usableCredits: map['usableCredits'] as int? ?? 0,
      payingAccountId: map['payingAccountId'] as String?,
      blocked: map['blocked'] as bool? ?? false,
      nextExpiryUtc: map['nextExpiryUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['nextExpiryUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory MemberCreditStatus.fromJson(String source) =>
      MemberCreditStatus.fromMap(json.decode(source) as Map<String, dynamic>);

  final String membername;

  /// Credit usable on this programme right now, across accounts.
  final int usableCredits;

  /// The account that would pay for the next occurrence, if any.
  final String? payingAccountId;

  /// No usable credit: the member stays enrolled but cannot be marked.
  final bool blocked;

  /// When the paying credit next lapses.
  final DateTime? nextExpiryUtc;

  MemberCreditStatus copyWith({
    String? membername,
    int? usableCredits,
    String? Function()? payingAccountId,
    bool? blocked,
    DateTime? Function()? nextExpiryUtc,
  }) {
    return MemberCreditStatus(
      membername: membername ?? this.membername,
      usableCredits: usableCredits ?? this.usableCredits,
      payingAccountId: payingAccountId != null
          ? payingAccountId()
          : this.payingAccountId,
      blocked: blocked ?? this.blocked,
      nextExpiryUtc: nextExpiryUtc != null
          ? nextExpiryUtc()
          : this.nextExpiryUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'membername': membername,
      'usableCredits': usableCredits,
      'payingAccountId': payingAccountId,
      'blocked': blocked,
      'nextExpiryUtc': nextExpiryUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'MemberCreditStatus(membername: $membername, '
      'usableCredits: $usableCredits, payingAccountId: $payingAccountId, '
      'blocked: $blocked, nextExpiryUtc: $nextExpiryUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberCreditStatus &&
        other.membername == membername &&
        other.usableCredits == usableCredits &&
        other.payingAccountId == payingAccountId &&
        other.blocked == blocked &&
        other.nextExpiryUtc == nextExpiryUtc;
  }

  @override
  int get hashCode => Object.hash(
    membername,
    usableCredits,
    payingAccountId,
    blocked,
    nextExpiryUtc,
  );
}
