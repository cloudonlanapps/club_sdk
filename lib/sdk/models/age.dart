import 'dart:convert';

import 'package:meta/meta.dart';

/// A length of time counted the way a person's age is: years, months and
/// days (club_server#16, #7).
///
/// The unit of the age band on events and groups (`minAge`, `maxAge`). The
/// server accepts years 0–150, months 0–11 and days 0–30, so "17 months" is
/// written as one year and five months; anything else answers 422.
@immutable
class Age {
  const Age({required this.years, this.months = 0, this.days = 0});

  factory Age.fromMap(Map<String, dynamic> map) {
    return Age(
      years: map['years'] as int,
      months: (map['months'] as int?) ?? 0,
      days: (map['days'] as int?) ?? 0,
    );
  }

  factory Age.fromJson(String source) =>
      Age.fromMap(json.decode(source) as Map<String, dynamic>);

  final int years;
  final int months;
  final int days;

  Age copyWith({int? years, int? months, int? days}) {
    return Age(
      years: years ?? this.years,
      months: months ?? this.months,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toMap() {
    return {'years': years, 'months': months, 'days': days};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'Age(years: $years, months: $months, days: $days)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Age &&
        other.years == years &&
        other.months == months &&
        other.days == days;
  }

  @override
  int get hashCode => Object.hash(years, months, days);
}
