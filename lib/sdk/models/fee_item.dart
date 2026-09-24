import 'dart:convert';

import 'package:meta/meta.dart';

/// One line of an event's fee structure (club_server#410, #22).
///
/// [amount] is in the deployment's currency (stored as INR on the server
/// and never exposed); [period] is free text such as `per month`.
@immutable
class FeeItem {
  const FeeItem({required this.name, required this.amount, this.period});

  factory FeeItem.fromMap(Map<String, dynamic> map) {
    return FeeItem(
      name: map['name'] as String,
      amount: map['amount'] as int,
      period: map['period'] as String?,
    );
  }

  factory FeeItem.fromJson(String source) =>
      FeeItem.fromMap(json.decode(source) as Map<String, dynamic>);

  /// What the line is for, e.g. `Camp fee`.
  final String name;

  /// The amount, whole units.
  final int amount;

  /// The billing period, when the amount recurs; `null` for a one-time fee.
  final String? period;

  FeeItem copyWith({
    String? name,
    int? amount,
    String? Function()? period,
  }) {
    return FeeItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period != null ? period() : this.period,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'amount': amount, 'period': period};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'FeeItem(name: $name, amount: $amount, period: $period)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeeItem &&
        other.name == name &&
        other.amount == amount &&
        other.period == period;
  }

  @override
  int get hashCode => name.hashCode ^ amount.hashCode ^ period.hashCode;
}
