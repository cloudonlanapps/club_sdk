/// Gender of a user.
enum Gender {
  male,
  female,
  other,
  preferNotToSay;

  /// Parse from server string (e.g. "prefer_not_to_say" → preferNotToSay).
  factory Gender.fromName(String name) {
    return Gender.values.firstWhere(
      (e) => e.name == name || e.serverValue == name,
      orElse: () => Gender.preferNotToSay,
    );
  }

  /// The snake_case value the server expects/sends.
  String get serverValue {
    return switch (this) {
      Gender.male => 'male',
      Gender.female => 'female',
      Gender.other => 'other',
      Gender.preferNotToSay => 'prefer_not_to_say',
    };
  }

  /// Human-readable display label.
  String get label {
    return switch (this) {
      Gender.male => 'Male',
      Gender.female => 'Female',
      Gender.other => 'Other',
      Gender.preferNotToSay => 'Prefer not to say',
    };
  }
}
