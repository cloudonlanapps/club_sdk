/// Kind of a group, set by the server based on criteria and the semiAuto flag.
enum GroupKind {
  manual,
  semiAuto,
  auto;

  /// Parse from the server string (`"manual" | "semi_auto" | "auto"`).
  factory GroupKind.fromServer(String value) {
    return switch (value) {
      'manual' => GroupKind.manual,
      'semi_auto' => GroupKind.semiAuto,
      'auto' => GroupKind.auto,
      _ => GroupKind.manual,
    };
  }

  /// The snake_case value the server uses.
  String get serverValue {
    return switch (this) {
      GroupKind.manual => 'manual',
      GroupKind.semiAuto => 'semi_auto',
      GroupKind.auto => 'auto',
    };
  }

  /// Human-readable display label.
  String get label {
    return switch (this) {
      GroupKind.manual => 'Manual',
      GroupKind.semiAuto => 'Semi-auto',
      GroupKind.auto => 'Auto',
    };
  }
}
