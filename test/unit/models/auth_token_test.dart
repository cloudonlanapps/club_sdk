import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Auth Token Model Unit Tests.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('AuthToken', () {
    final expiresAt = DateTime.utc(2024, 6, 15, 12);
    final token = AuthToken(
      accessToken: 'abc123xyz',
      tokenType: 'Bearer',
      expiresAtUtc: expiresAt,
    );

    test('two instances with same values are equal', () {
      final sameToken = AuthToken(
        accessToken: 'abc123xyz',
        tokenType: 'Bearer',
        expiresAtUtc: expiresAt,
      );

      expect(token, sameToken);
    });

    test('two instances with different values are not equal', () {
      final differentToken = AuthToken(
        accessToken: 'different',
        tokenType: 'Bearer',
        expiresAtUtc: expiresAt,
      );

      expect(token, isNot(differentToken));
    });

    test('equal instances have same hashCode', () {
      final sameToken = AuthToken(
        accessToken: 'abc123xyz',
        tokenType: 'Bearer',
        expiresAtUtc: expiresAt,
      );

      expect(token.hashCode, sameToken.hashCode);
    });

    test('copyWith creates new instance with changed field', () {
      final newExpiry = DateTime.utc(2024, 6, 16, 12);
      final updated = token.copyWith(expiresAtUtc: newExpiry);
      expect(updated.accessToken, token.accessToken);
      expect(updated.tokenType, token.tokenType);
      expect(updated.expiresAtUtc, newExpiry);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = token.copyWith(tokenType: 'JWT');
      expect(updated.accessToken, 'abc123xyz');
      expect(updated.tokenType, 'JWT');
      expect(updated.expiresAtUtc, expiresAt);
    });

    test('toMap produces correct map structure', () {
      final map = token.toMap();
      expect(map['accessToken'], 'abc123xyz');
      expect(map['tokenType'], 'Bearer');
      expect(map['expiresAtUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = token.toMap();
      final fromMap = AuthToken.fromMap(map);
      expect(fromMap, token);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = AuthToken.fromMap(token.toMap());
      expect(restored, token);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = token.toJson();
      final fromJson = AuthToken.fromJson(json);
      expect(fromJson, token);
    });
  });
}
