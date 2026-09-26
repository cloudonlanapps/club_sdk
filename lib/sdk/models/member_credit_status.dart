import 'dart:convert';

import 'package:meta/meta.dart';

/// One row of a programme's credit roster (#14): whether an enrolled
/// member can be marked, which account would pay, and whether their
/// departure needs a `CreditDisposition` ([boundCredits] > 0).
@immutable
class MemberCreditStatus {
  const MemberCreditStatus({
    required this.membername,
    required this.usableCredits,
    required this.blocked,
    this.boundCredits = 0,
    this.payingAccountId,
    this.nextExpiryUtc,
  });

  factory MemberCreditStatus.fromMap(Map<String, dynamic> map) {
    return MemberCreditStatus(
      membername: map['membername'] as String,
      usableCredits: map['usableCredits'] as int? ?? 0,
      boundCredits: map['boundCredits'] as int? ?? 0,
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

  /// Unsettled credit held in accounts bound to this programme, expired
  /// ones included, general ones not.
  ///
  /// Independent of [usableCredits]: an expired package gives usable 0
  /// and bound > 0, general-only credit the reverse. When it is above 0,
  /// removing the member or approving their withdrawal needs a
  /// `CreditDisposition` (422 `CREDIT_DISPOSITION_REQUIRED` otherwise).
  /// Reads 0 from a server that predates it.
  final int boundCredits;

  /// The account that would pay for the next occurrence, if any.
  final String? payingAccountId;

  /// No usable credit: the member stays enrolled but cannot be marked.
  final bool blocked;

  /// When the paying credit next lapses.
  final DateTime? nextExpiryUtc;

  MemberCreditStatus copyWith({
    String? membername,
    int? usableCredits,
    int? boundCredits,
    String? Function()? payingAccountId,
    bool? blocked,
    DateTime? Function()? nextExpiryUtc,
  }) {
    return MemberCreditStatus(
      membername: membername ?? this.membername,
      usableCredits: usableCredits ?? this.usableCredits,
      boundCredits: boundCredits ?? this.boundCredits,
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
      'boundCredits': boundCredits,
      'payingAccountId': payingAccountId,
      'blocked': blocked,
      'nextExpiryUtc': nextExpiryUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'MemberCreditStatus(membername: $membername, '
      'usableCredits: $usableCredits, boundCredits: $boundCredits, '
      'payingAccountId: $payingAccountId, '
      'blocked: $blocked, nextExpiryUtc: $nextExpiryUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberCreditStatus &&
        other.membername == membername &&
        other.usableCredits == usableCredits &&
        other.boundCredits == boundCredits &&
        other.payingAccountId == payingAccountId &&
        other.blocked == blocked &&
        other.nextExpiryUtc == nextExpiryUtc;
  }

  @override
  int get hashCode => Object.hash(
    membername,
    usableCredits,
    boundCredits,
    payingAccountId,
    blocked,
    nextExpiryUtc,
  );
}
