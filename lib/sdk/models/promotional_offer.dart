import 'dart:convert';

import 'package:meta/meta.dart';

/// A time-boxed promotion on an event's extended marketing block
/// (club_server#410, #22), e.g. an early-bird discount.
@immutable
class PromotionalOffer {
  const PromotionalOffer({
    required this.title,
    this.description,
    this.validUntilUtc,
  });

  factory PromotionalOffer.fromMap(Map<String, dynamic> map) {
    return PromotionalOffer(
      title: map['title'] as String,
      description: map['description'] as String?,
      validUntilUtc: map['validUntilUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['validUntilUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory PromotionalOffer.fromJson(String source) =>
      PromotionalOffer.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The offer's headline, e.g. `Early bird`.
  final String title;

  /// The terms, in a sentence.
  final String? description;

  /// When the offer lapses; `null` when open-ended.
  final DateTime? validUntilUtc;

  /// Whether the offer has lapsed at [now]; never, when open-ended.
  bool isExpired(DateTime now) =>
      validUntilUtc != null && !now.isBefore(validUntilUtc!);

  PromotionalOffer copyWith({
    String? title,
    String? Function()? description,
    DateTime? Function()? validUntilUtc,
  }) {
    return PromotionalOffer(
      title: title ?? this.title,
      description: description != null ? description() : this.description,
      validUntilUtc: validUntilUtc != null
          ? validUntilUtc()
          : this.validUntilUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'validUntilUtc': validUntilUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PromotionalOffer(title: $title, description: $description, '
      'validUntilUtc: $validUntilUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromotionalOffer &&
        other.title == title &&
        other.description == description &&
        other.validUntilUtc == validUntilUtc;
  }

  @override
  int get hashCode =>
      title.hashCode ^ description.hashCode ^ validUntilUtc.hashCode;
}
