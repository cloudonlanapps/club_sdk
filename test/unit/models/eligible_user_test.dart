import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('EligibleUser', () {
    const full = EligibleUser(
      username: 'alice',
      firstName: 'Alice',
      lastName: 'Anderson',
      nickname: 'Al',
    );

    const minimal = EligibleUser(username: 'bob');

    test('round-trips through toMap / fromMap', () {
      expect(EligibleUser.fromMap(full.toMap()), full);
      expect(EligibleUser.fromMap(minimal.toMap()), minimal);
    });

    test('round-trips through toJson / fromJson', () {
      expect(EligibleUser.fromJson(full.toJson()), full);
    });

    test('equality is value-based', () {
      const same = EligibleUser(
        username: 'alice',
        firstName: 'Alice',
        lastName: 'Anderson',
        nickname: 'Al',
      );
      expect(full, same);
      expect(full.hashCode, same.hashCode);
    });

    test('two users with different usernames are not equal', () {
      expect(full == const EligibleUser(username: 'someone-else'), isFalse);
    });

    test('copyWith replaces non-null fields', () {
      final renamed = full.copyWith(firstName: () => 'Alicia');
      expect(renamed.firstName, 'Alicia');
      expect(renamed.lastName, full.lastName);
    });

    test('copyWith clears nullable fields via ValueGetter', () {
      final stripped = full.copyWith(
        firstName: () => null,
        lastName: () => null,
        nickname: () => null,
      );
      expect(stripped.firstName, isNull);
      expect(stripped.lastName, isNull);
      expect(stripped.nickname, isNull);
      expect(stripped.username, full.username);
    });
  });
}
