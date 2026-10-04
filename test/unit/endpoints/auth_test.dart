import 'package:club_sdk_2/remote_store/endpoints/auth.dart';
import 'package:test/test.dart';

void main() {
  const ep = AuthEndpoints();

  group('AuthEndpoints', () {
    test('register', () => expect(ep.register, '/auth/register'));
    test('login', () => expect(ep.login, '/auth/login'));
    test('logout', () => expect(ep.logout, '/auth/logout'));
    test(
      'resetPassword',
      () => expect(ep.resetPassword, '/auth/reset-password'),
    );
    test('me', () => expect(ep.me, '/auth/me'));
    test('refresh', () => expect(ep.refresh, '/auth/refresh'));
    test(
      'changePassword',
      () => expect(ep.changePassword, '/auth/change-password'),
    );
    test(
      'usernameAvailable',
      () => expect(ep.usernameAvailable, '/auth/username-available'),
    );
  });
}
