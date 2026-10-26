import 'package:meta/meta.dart';

/// How the server fits an application's form, decided when the template
/// is saved (club_server#93, R13, R16) and dropped when it is reverted.
///
/// [name] is the first layout whose page 1 fits: `one page`,
/// `one page, tighter spacing` or `signing part on page 2`. The spreads are
/// the spare height, in points, added to each gap of page 1 with and
/// without the parent / guardian block — the one part that varies by
/// member.
@immutable
class ApplicationLayout {
  const ApplicationLayout({
    required this.name,
    required this.spreadWithGuardian,
    required this.spreadWithoutGuardian,
  });

  factory ApplicationLayout.fromMap(Map<String, dynamic> map) {
    final spread = map['spread'] as Map<String, dynamic>? ?? const {};
    return ApplicationLayout(
      name: map['name'] as String,
      spreadWithGuardian: (spread['withGuardian'] as num?)?.toDouble() ?? 0,
      spreadWithoutGuardian:
          (spread['withoutGuardian'] as num?)?.toDouble() ?? 0,
    );
  }

  /// The layout's name.
  final String name;

  /// Page 1's spread, in points, when the guardian block is printed.
  final double spreadWithGuardian;

  /// Page 1's spread, in points, without the guardian block.
  final double spreadWithoutGuardian;

  Map<String, dynamic> toMap() => {
    'name': name,
    'spread': {
      'withGuardian': spreadWithGuardian,
      'withoutGuardian': spreadWithoutGuardian,
    },
  };

  @override
  String toString() =>
      'ApplicationLayout($name, withGuardian: $spreadWithGuardian, '
      'withoutGuardian: $spreadWithoutGuardian)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationLayout &&
          other.name == name &&
          other.spreadWithGuardian == spreadWithGuardian &&
          other.spreadWithoutGuardian == spreadWithoutGuardian;

  @override
  int get hashCode =>
      Object.hash(name, spreadWithGuardian, spreadWithoutGuardian);
}
