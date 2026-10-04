import 'dart:convert';

import 'package:meta/meta.dart';

import 'credit_entry_type.dart';

/// One line of the append-only credit ledger (#14).
///
/// [amount] is signed: a deduction is negative. A
/// [CreditEntryType.validityExtended] entry carries zero. [offsetsEntryId]
/// names the entry this one reverses (a refund names its deduction, a
/// reversal its grant). [balanceAfter] and [totalAfter] are the running
/// figures a statement shows beside each line.
@immutable
class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.accountId,
    required this.membername,
    required this.amount,
    required this.entryType,
    required this.reason,
    required this.createdAtUtc,
    this.eventId,
    this.occurrenceTimeUtc,
    this.actorUsername,
    this.offsetsEntryId,
    this.balanceAfter,
    this.totalAfter,
  });

  factory CreditEntry.fromMap(Map<String, dynamic> map) {
    return CreditEntry(
      id: map['id'] as int,
      accountId: map['accountId'] as String,
      membername: map['membername'] as String,
      amount: map['amount'] as int,
      entryType: CreditEntryType.fromWire(map['entryType'] as String),
      eventId: map['eventId'] as int?,
      occurrenceTimeUtc: map['occurrenceTimeUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['occurrenceTimeUtc'] as int,
              isUtc: true,
            )
          : null,
      reason: map['reason'] as String? ?? '',
      actorUsername: map['actorUsername'] as String?,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      offsetsEntryId: map['offsetsEntryId'] as int?,
      balanceAfter: map['balanceAfter'] as int?,
      totalAfter: map['totalAfter'] as int?,
    );
  }

  factory CreditEntry.fromJson(String source) =>
      CreditEntry.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String accountId;
  final String membername;

  /// Signed; negative is a deduction.
  final int amount;
  final CreditEntryType entryType;

  /// The programme a charge or refund concerns.
  final int? eventId;

  /// The occurrence a charge or refund concerns.
  final DateTime? occurrenceTimeUtc;
  final String reason;

  /// Who caused the movement; null where the server acted on its own
  /// (a sweep, a cancellation refund).
  final String? actorUsername;
  final DateTime createdAtUtc;

  /// The entry this one reverses.
  final int? offsetsEntryId;

  /// The account's balance after this entry, whatever filter or page the
  /// listing used. Null from a server that predates it.
  final int? balanceAfter;

  /// The member's credit across all their accounts after this entry; a
  /// transfer between their own accounts leaves it unchanged. Null from a
  /// server that predates it.
  final int? totalAfter;

  CreditEntry copyWith({
    int? id,
    String? accountId,
    String? membername,
    int? amount,
    CreditEntryType? entryType,
    int? Function()? eventId,
    DateTime? Function()? occurrenceTimeUtc,
    String? reason,
    String? Function()? actorUsername,
    DateTime? createdAtUtc,
    int? Function()? offsetsEntryId,
    int? Function()? balanceAfter,
    int? Function()? totalAfter,
  }) {
    return CreditEntry(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      membername: membername ?? this.membername,
      amount: amount ?? this.amount,
      entryType: entryType ?? this.entryType,
      eventId: eventId != null ? eventId() : this.eventId,
      occurrenceTimeUtc: occurrenceTimeUtc != null
          ? occurrenceTimeUtc()
          : this.occurrenceTimeUtc,
      reason: reason ?? this.reason,
      actorUsername: actorUsername != null
          ? actorUsername()
          : this.actorUsername,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      offsetsEntryId: offsetsEntryId != null
          ? offsetsEntryId()
          : this.offsetsEntryId,
      balanceAfter: balanceAfter != null ? balanceAfter() : this.balanceAfter,
      totalAfter: totalAfter != null ? totalAfter() : this.totalAfter,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'membername': membername,
      'amount': amount,
      'entryType': entryType.wireName,
      'eventId': eventId,
      'occurrenceTimeUtc': occurrenceTimeUtc?.millisecondsSinceEpoch,
      'reason': reason,
      'actorUsername': actorUsername,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'offsetsEntryId': offsetsEntryId,
      'balanceAfter': balanceAfter,
      'totalAfter': totalAfter,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'CreditEntry(id: $id, accountId: $accountId, amount: $amount, '
      'entryType: $entryType, eventId: $eventId, '
      'occurrenceTimeUtc: $occurrenceTimeUtc, balanceAfter: $balanceAfter, '
      'totalAfter: $totalAfter)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditEntry &&
        other.id == id &&
        other.accountId == accountId &&
        other.membername == membername &&
        other.amount == amount &&
        other.entryType == entryType &&
        other.eventId == eventId &&
        other.occurrenceTimeUtc == occurrenceTimeUtc &&
        other.reason == reason &&
        other.actorUsername == actorUsername &&
        other.createdAtUtc == createdAtUtc &&
        other.offsetsEntryId == offsetsEntryId &&
        other.balanceAfter == balanceAfter &&
        other.totalAfter == totalAfter;
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    membername,
    amount,
    entryType,
    eventId,
    occurrenceTimeUtc,
    reason,
    actorUsername,
    createdAtUtc,
    offsetsEntryId,
    balanceAfter,
    totalAfter,
  );
}
