import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'club_history_data.dart';
import 'club_value_card_data.dart';

/// Club page specific information (history, values).
///
/// Separate from PageData to allow reuse of PageDataScaffold.
@immutable
class ClubInfo {
  const ClubInfo({required this.history, required this.values});

  factory ClubInfo.fromMap(Map<String, dynamic> map) {
    final valuesList = map['values'] as List<dynamic>?;
    return ClubInfo(
      history: ClubHistoryData.fromMap(
        map['history'] as Map<String, dynamic>? ?? {},
      ),
      values:
          valuesList
              ?.map((e) => ClubValueCardData.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ClubInfo.fromJson(String source) =>
      ClubInfo.fromMap(json.decode(source) as Map<String, dynamic>);

  final ClubHistoryData history;
  final List<ClubValueCardData> values;

  ClubInfo copyWith({
    ClubHistoryData? history,
    List<ClubValueCardData>? values,
  }) {
    return ClubInfo(
      history: history ?? this.history,
      values: values ?? this.values,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'history': history.toMap(),
      'values': values.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClubInfo(history: $history, values: $values)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is ClubInfo &&
        other.history == history &&
        listEquals(other.values, values);
  }

  @override
  int get hashCode => history.hashCode ^ values.hashCode;
}
