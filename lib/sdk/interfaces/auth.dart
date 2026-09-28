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
  ///
  /// A blocked user is refused with 401 `ACCOUNT_BLOCKED` and a user who has
  /// left with 401 `ACCOUNT_LEFT` (club_server#507); no token is stored.
  Future<AuthToken> login(String username, String password);

  /// Public, unauthenticated check: is `username` still available?
  ///
  /// Returns `true` if no user holds this username, soft-deleted users
  /// included (club_server#505) so that it agrees with `register`'s 409,
  /// and the value passes basic format validation server-side, `false`
  /// otherwise. Intended for inline registration-form feedback so the
  /// caller can short-circuit a doomed POST `/auth/register`. Hits
  /// `GET /auth/username-available?username=<value>` and does not
  /// require a bearer token.
  Future<bool> isUsernameAvailable(String username);

  /// Logout the current user, ending this session only (club_server#510).
  ///
  /// The server revokes the access token presented and the refresh token
  /// issued with it; other sessions of the same user keep working. Any
  /// logged-in user may log out, whatever their status.
  ///
  /// The session's refresh token is sent in the body: [refreshToken] if
  /// given (an app that restored a saved session), otherwise the one from
  /// this client's latest [login] or [refreshToken] call.
  ///
  /// Always signs the client out locally: the token is cleared even when
  /// the server refuses, and the refusal is then rethrown.
  Future<void> logout({String? refreshToken});

  /// Request password reset for the given email.
  ///
  /// The address is matched ignoring case (club_server#508). The server
  /// answers alike whether or not an account exists.
  Future<void> resetPassword(String email);

  /// Get the currently authenticated user's private profile.
  Future<UserPrivate> getCurrentUser();

  /// Refresh the access token using a refresh token.
  Future<AuthToken> refreshToken(String refreshToken);

  /// Change the current user's password.
  ///
  /// Any logged-in user may, whatever their status (club_server#510).
  /// Requires verification of the current password before updating.
  /// Throws `InvalidCredentialsException` if currentPassword is incorrect.
  /// Throws `NotAuthenticatedException` if no user is logged in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
