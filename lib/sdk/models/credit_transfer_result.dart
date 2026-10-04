import 'dart:convert';

import 'package:meta/meta.dart';

import 'credit_account.dart';

/// What a transfer did (#14): [source] is the account it closed and
/// [created] the general account that received what survived the penalty,
/// or null when the penalty consumed the whole balance.
@immutable
class CreditTransferResult {
  const CreditTransferResult({required this.source, this.created});

  factory CreditTransferResult.fromMap(Map<String, dynamic> map) {
    return CreditTransferResult(
      source: CreditAccount.fromMap(map['source'] as Map<String, dynamic>),
      created: map['created'] != null
          ? CreditAccount.fromMap(map['created'] as Map<String, dynamic>)
          : null,
    );
  }

  factory CreditTransferResult.fromJson(String source) =>
      CreditTransferResult.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The account the transfer closed.
  final CreditAccount source;

  /// The general account opened with the remainder; null when nothing
  /// survived the penalty.
  final CreditAccount? created;

  CreditTransferResult copyWith({
    CreditAccount? source,
    CreditAccount? Function()? created,
  }) {
    return CreditTransferResult(
      source: source ?? this.source,
      created: created != null ? created() : this.created,
    );
  }

  Map<String, dynamic> toMap() {
    return {'source': source.toMap(), 'created': created?.toMap()};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'CreditTransferResult(source: $source, created: $created)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditTransferResult &&
        other.source == source &&
        other.created == created;
  }

  @override
  int get hashCode => Object.hash(source, created);
}
