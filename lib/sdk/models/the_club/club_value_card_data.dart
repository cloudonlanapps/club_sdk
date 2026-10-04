import 'dart:convert';
import 'package:meta/meta.dart';

/// Value card data (Mission, Vision, Values) for Club page.
@immutable
class ClubValueCardData {
  const ClubValueCardData({
    required this.iconName,
    required this.title,
    required this.description,
  });

  factory ClubValueCardData.fromMap(Map<String, dynamic> map) {
    return ClubValueCardData(
      iconName: map['iconName'] as String? ?? 'target',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
    );
  }

  factory ClubValueCardData.fromJson(String source) =>
      ClubValueCardData.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Lucide icon name: 'target', 'eye', 'heart', etc.
  final String iconName;
  final String title;
  final String description;

  ClubValueCardData copyWith({
    String? iconName,
    String? title,
    String? description,
  }) {
    return ClubValueCardData(
      iconName: iconName ?? this.iconName,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {'iconName': iconName, 'title': title, 'description': description};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClubValueCardData(iconName: $iconName, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClubValueCardData &&
        other.iconName == iconName &&
        other.title == title &&
        other.description == description;
  }

  @override
  int get hashCode => iconName.hashCode ^ title.hashCode ^ description.hashCode;
}
