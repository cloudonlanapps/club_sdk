import 'package:meta/meta.dart';

@immutable
class AuthEndpoints {
  const AuthEndpoints();

  String get register => '/auth/register';
  String get usernameAvailable => '/auth/username-available';
  String get login => '/auth/login';
  String get logout => '/auth/logout';
  String get resetPassword => '/auth/reset-password';
  String get me => '/auth/me';
  String get refresh => '/auth/refresh';
  String get changePassword => '/auth/change-password';
}
