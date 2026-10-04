import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// History section data for Club page.
@immutable
class ClubHistoryData {
  const ClubHistoryData({required this.paragraphs});

  factory ClubHistoryData.fromMap(Map<String, dynamic> map) {
    final paragraphsList = map['paragraphs'] as List<dynamic>?;
    return ClubHistoryData(paragraphs: paragraphsList?.cast<String>() ?? []);
  }

  factory ClubHistoryData.fromJson(String source) =>
      ClubHistoryData.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<String> paragraphs;

  /// Combined paragraphs as single text with double newlines.
  String get text => paragraphs.join('\n\n');

  ClubHistoryData copyWith({String? title, List<String>? paragraphs}) {
    return ClubHistoryData(paragraphs: paragraphs ?? this.paragraphs);
  }

  Map<String, dynamic> toMap() {
    return {'paragraphs': paragraphs};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClubHistoryData($paragraphs)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is ClubHistoryData && listEquals(other.paragraphs, paragraphs);
  }

  @override
  int get hashCode => paragraphs.hashCode;
}
