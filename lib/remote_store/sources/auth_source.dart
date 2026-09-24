import '../../sdk/interfaces/auth.dart';
import '../../sdk/models/auth_token.dart';
import '../../sdk/models/gender.dart';
import '../../sdk/models/user.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [AuthSource] using HTTP API.
class RemoteAuthSource implements AuthSource {
  RemoteAuthSource(this._store);

  final RemoteStore _store;

  @override
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
  }) async {
    final response = await _store.post(
      endpoints.auth.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'phone': phone,
        'dateOfBirthUtc': dateOfBirthUtc.millisecondsSinceEpoch,
        'gender': gender.serverValue,
        'firstName': ?firstName,
        'middleName': ?middleName,
        'lastName': ?lastName,
      },
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final response = await _store.get(
      endpoints.auth.usernameAvailable,
      queryParams: {'username': username},
    );
    return response['available'] as bool;
  }

  @override
  Future<AuthToken> login(String username, String password) async {
    final response = await _store.post(
      endpoints.auth.login,
      body: {'username': username, 'password': password},
    );
    final token = AuthToken.fromMap(response);
    _store.authToken = token.accessToken;
    return token;
  }

  @override
  Future<void> logout() async {
    await _store.postVoid(endpoints.auth.logout);
    _store.authToken = null;
  }

  @override
  Future<void> resetPassword(String email) async {
    await _store.postVoid(endpoints.auth.resetPassword, body: {'email': email});
  }

  @override
  Future<UserPrivate> getCurrentUser() async {
    final response = await _store.get(endpoints.auth.me);
    return UserPrivate.fromMap(response);
  }

  @override
  Future<AuthToken> refreshToken(String refreshToken) async {
    final response = await _store.post(
      endpoints.auth.refresh,
      body: {'refreshToken': refreshToken},
    );
    final token = AuthToken.fromMap(response);
    _store.authToken = token.accessToken;
    return token;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _store.postVoid(
      endpoints.auth.changePassword,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
