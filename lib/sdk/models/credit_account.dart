import 'dart:convert';

import 'package:meta/meta.dart';

import 'credit_account_kind.dart';
import 'credit_account_state.dart';

/// A member's credit account (#14).
///
/// A member has no single balance; they hold accounts. Each has an
/// 8-character code, is bound to one programme or general, and carries a
/// validity window. An account is never topped up — more credit means a
/// new account — and its balance is derived from an append-only ledger.
@immutable
class CreditAccount {
  const CreditAccount({
    required this.accountId,
    required this.membername,
    required this.kind,
    required this.isTrial,
    required this.balance,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.usable,
    required this.state,
    required this.openedAtUtc,
    this.eventId,
    this.openedBy,
    this.closedAtUtc,
  });

  factory CreditAccount.fromMap(Map<String, dynamic> map) {
    return CreditAccount(
      accountId: map['accountId'] as String,
      membername: map['membername'] as String,
      kind: CreditAccountKind.fromWire(map['kind'] as String),
      eventId: map['eventId'] as int?,
      isTrial: map['isTrial'] as bool? ?? false,
      balance: map['balance'] as int,
      validFromUtc: DateTime.fromMillisecondsSinceEpoch(
        map['validFromUtc'] as int,
        isUtc: true,
      ),
      validUntilUtc: DateTime.fromMillisecondsSinceEpoch(
        map['validUntilUtc'] as int,
        isUtc: true,
      ),
      usable: map['usable'] as bool? ?? false,
      state: CreditAccountState.fromWire(map['state'] as String),
      openedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['openedAtUtc'] as int,
        isUtc: true,
      ),
      openedBy: map['openedBy'] as String?,
      closedAtUtc: map['closedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['closedAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory CreditAccount.fromJson(String source) =>
      CreditAccount.fromMap(json.decode(source) as Map<String, dynamic>);

  /// 8-character letter-and-digit code, server generated, unique.
  final String accountId;

  /// The owner.
  final String membername;

  /// Bound to one programme or general.
  final CreditAccountKind kind;

  /// The programme this account pays for; null for a general account.
  final int? eventId;

  /// Trial accounts fund trial enrollments only, and never mix with
  /// ordinary credit in either direction.
  final bool isTrial;

  /// Derived from the ledger, never stored.
  final int balance;

  final DateTime validFromUtc;
  final DateTime validUntilUtc;

  /// Inside the validity window with a positive balance.
  final bool usable;

  final CreditAccountState state;
  final DateTime openedAtUtc;

  /// The admin who opened it.
  final String? openedBy;

  /// Set when a transfer closes the account.
  final DateTime? closedAtUtc;

  CreditAccount copyWith({
    String? accountId,
    String? membername,
    CreditAccountKind? kind,
    int? Function()? eventId,
    bool? isTrial,
    int? balance,
    DateTime? validFromUtc,
    DateTime? validUntilUtc,
    bool? usable,
    CreditAccountState? state,
    DateTime? openedAtUtc,
    String? Function()? openedBy,
    DateTime? Function()? closedAtUtc,
  }) {
    return CreditAccount(
      accountId: accountId ?? this.accountId,
      membername: membername ?? this.membername,
      kind: kind ?? this.kind,
      eventId: eventId != null ? eventId() : this.eventId,
      isTrial: isTrial ?? this.isTrial,
      balance: balance ?? this.balance,
      validFromUtc: validFromUtc ?? this.validFromUtc,
      validUntilUtc: validUntilUtc ?? this.validUntilUtc,
      usable: usable ?? this.usable,
      state: state ?? this.state,
      openedAtUtc: openedAtUtc ?? this.openedAtUtc,
      openedBy: openedBy != null ? openedBy() : this.openedBy,
      closedAtUtc: closedAtUtc != null ? closedAtUtc() : this.closedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'membername': membername,
      'kind': kind.wireName,
      'eventId': eventId,
      'isTrial': isTrial,
      'balance': balance,
      'validFromUtc': validFromUtc.millisecondsSinceEpoch,
      'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
      'usable': usable,
      'state': state.wireName,
      'openedAtUtc': openedAtUtc.millisecondsSinceEpoch,
      'openedBy': openedBy,
      'closedAtUtc': closedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'CreditAccount(accountId: $accountId, membername: $membername, '
      'kind: $kind, eventId: $eventId, isTrial: $isTrial, '
      'balance: $balance, state: $state)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditAccount &&
        other.accountId == accountId &&
        other.membername == membername &&
        other.kind == kind &&
        other.eventId == eventId &&
        other.isTrial == isTrial &&
        other.balance == balance &&
        other.validFromUtc == validFromUtc &&
        other.validUntilUtc == validUntilUtc &&
        other.usable == usable &&
        other.state == state &&
        other.openedAtUtc == openedAtUtc &&
        other.openedBy == openedBy &&
        other.closedAtUtc == closedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    membername,
    kind,
    eventId,
    isTrial,
    balance,
    validFromUtc,
    validUntilUtc,
    usable,
    state,
    openedAtUtc,
    openedBy,
    closedAtUtc,
  );
}
