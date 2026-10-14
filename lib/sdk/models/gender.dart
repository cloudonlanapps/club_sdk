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

/// The gender criterion of an event or a group as the server sends it:
/// `genders`, or the single `gender` of a server from before
/// club_server#25 and #26. Empty is no criterion.
List<Gender> gendersFromMap(Map<String, dynamic> map) {
  final genders = map['genders'];
  if (genders is List) {
    return List.unmodifiable(genders.map((g) => Gender.fromName(g as String)));
  }
  final gender = map['gender'];
  return gender is String
      ? List.unmodifiable([Gender.fromName(gender)])
      : const [];
}

/// [genders] as the server takes them.
List<String> gendersToServer(List<Gender> genders) => [
  for (final gender in genders) gender.serverValue,
];

/// The `genders` a create sends: [genders], or the deprecated single
/// [gender] as a list of one; `null` when neither is given. Giving both is
/// an [ArgumentError], as the server refuses both (club_server#25, #26).
List<String>? gendersForCreate(List<Gender>? genders, Gender? gender) {
  if (genders != null && gender != null) {
    throw ArgumentError('Send genders or the deprecated gender, not both');
  }
  if (genders != null) return gendersToServer(genders);
  return gender == null ? null : [gender.serverValue];
}

/// The `genders` an update sends: the list from [genders], or the
/// deprecated single [gender] as a list of one (empty when it returns
/// `null`); `null` when neither getter is given, which leaves the criterion
/// alone. An empty list clears it. Giving both is an [ArgumentError].
List<String>? gendersForUpdate(
  List<Gender> Function()? genders,
  Gender? Function()? gender,
) {
  if (genders != null && gender != null) {
    throw ArgumentError('Send genders or the deprecated gender, not both');
  }
  if (genders != null) return gendersToServer(genders());
  if (gender == null) return null;
  final single = gender();
  return single == null ? const [] : [single.serverValue];
}
