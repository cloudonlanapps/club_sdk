import '../models/auth_token.dart';
import '../models/gender.dart';
import '../models/user.dart';

/// Interface for authentication operations.
abstract interface class AuthSource {
  /// Register a new user with the provided details.
  ///
  /// The `username` is the unique identifier and primary key for the user.
  Future<UserInfo> register({
    required String username,
    required String email,
    required String password,
    required String phone,
    required DateTime dateOfBirthUtc,
    required Gender gender,
    String? firstName,
    String? middleName,
    String? lastName,
  });

  /// Login with username and password.
  Future<AuthToken> login(String username, String password);

  /// Public, unauthenticated check: is `username` still available?
  ///
  /// Returns `true` if no active user is registered with this username
  /// and the value passes basic format validation server-side, `false`
  /// otherwise. Intended for inline registration-form feedback so the
  /// caller can short-circuit a doomed POST `/auth/register`. Hits
  /// `GET /auth/username-available?username=<value>` and does not
  /// require a bearer token.
  Future<bool> isUsernameAvailable(String username);

  /// Logout the current user.
  Future<void> logout();

  /// Request password reset for the given email.
  Future<void> resetPassword(String email);

  /// Get the currently authenticated user's private profile.
  Future<UserPrivate> getCurrentUser();

  /// Refresh the access token using a refresh token.
  Future<AuthToken> refreshToken(String refreshToken);

  /// Change the current user's password.
  ///
  /// Requires verification of the current password before updating.
  /// Throws `InvalidCredentialsException` if currentPassword is incorrect.
  /// Throws `NotAuthenticatedException` if no user is logged in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
