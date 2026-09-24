import '../../sdk/interfaces/user.dart';
import '../../sdk/models/address.dart';
import '../../sdk/models/gender.dart';
import '../../sdk/models/pagination.dart';
import '../../sdk/models/user.dart';
import '../../sdk/models/user_counts.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [UserSource] using HTTP API.
class RemoteUserSource implements UserSource {
  RemoteUserSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<UserInfo>> getUsers({
    int offset = 0,
    int limit = 20,
    UserStatus? status,
    String? role,
    int? minAge,
    int? maxAge,
    String? searchTerm,
    String? sortBy,
    bool descending = false,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      if (status != null) 'status': status.name,
      'role': ?role,
      if (minAge != null) 'minAge': minAge.toString(),
      if (maxAge != null) 'maxAge': maxAge.toString(),
      'searchTerm': ?searchTerm,
      'sortBy': ?sortBy,
      'descending': descending.toString(),
    };
    final response = await _store.get(
      endpoints.users.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, UserInfo.fromMap);
  }

  @override
  Future<PaginatedList<UserInfo>> getDeletedUsers({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.users.deleted,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, UserInfo.fromMap);
  }

  @override
  Future<UserCounts> getUserCounts() async {
    final response = await _store.get(endpoints.users.count);
    return UserCounts.fromMap(response);
  }

  @override
  Future<UserInfo> getUserInfo(String username) async {
    final response = await _store.get(endpoints.users.user(username));
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserPrivate> getUserPrivate(String username) async {
    final response = await _store.get(endpoints.users.userPrivate(username));
    return UserPrivate.fromMap(response);
  }

  @override
  Future<UserPrivate> createUser({
    required String username,
    required String email,
    required String passwordHash,
    required String phone,
    required DateTime dateOfBirthUtc,
    required Gender gender,
    String? firstName,
    String? middleName,
    String? lastName,
    String? bio,
    String? achievements,
    String? emergencyContact,
    String? medicalNotes,
    UserStatus status = UserStatus.pending,
    Address? address,
    bool isGuest = false,
  }) async {
    final response = await _store.post(
      endpoints.users.list,
      body: {
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'phone': phone,
        'dateOfBirthUtc': dateOfBirthUtc.millisecondsSinceEpoch,
        'gender': gender.serverValue,
        'firstName': ?firstName,
        'middleName': ?middleName,
        'lastName': ?lastName,
        'bio': ?bio,
        'achievements': ?achievements,
        'emergencyContact': ?emergencyContact,
        'medicalInfo': ?medicalNotes,
        'status': status.name,
        if (address != null) 'address': address.toMap(),
        'isGuest': isGuest,
      },
    );
    return UserPrivate.fromMap(response);
  }

  @override
  Future<UserPrivate> updateUser(
    String username, {
    String? email,
    String? Function()? firstName,
    String? Function()? middleName,
    String? Function()? lastName,
    String? Function()? phone,
    DateTime? Function()? dateOfBirthUtc,
    String? Function()? bio,
    String? Function()? achievements,
    String? Function()? emergencyContact,
    String? Function()? medicalNotes,
    String? Function()? nickname,
    bool? useNamePublicly,
    Gender? Function()? gender,
    Address? Function()? address,
    bool? isPublicProfile,
  }) async {
    final body = <String, dynamic>{
      'email': ?email,
      'useNamePublicly': ?useNamePublicly,
      'isPublicProfile': ?isPublicProfile,
    };

    // Handle ValueGetter pattern for nullable fields
    if (firstName != null) {
      body['firstName'] = firstName();
    }
    if (middleName != null) {
      body['middleName'] = middleName();
    }
    if (lastName != null) {
      body['lastName'] = lastName();
    }
    if (phone != null) {
      body['phone'] = phone();
    }
    if (dateOfBirthUtc != null) {
      final dob = dateOfBirthUtc();
      body['dateOfBirthUtc'] = dob?.millisecondsSinceEpoch;
    }
    if (bio != null) {
      body['bio'] = bio();
    }
    if (achievements != null) {
      body['achievements'] = achievements();
    }
    if (emergencyContact != null) {
      body['emergencyContact'] = emergencyContact();
    }
    if (medicalNotes != null) {
      body['medicalInfo'] = medicalNotes();
    }
    if (nickname != null) {
      body['nickname'] = nickname();
    }
    if (gender != null) {
      final g = gender();
      body['gender'] = g?.serverValue;
    }
    if (address != null) {
      final a = address();
      body['address'] = a?.toMap();
    }

    final response = await _store.patch(
      endpoints.users.user(username),
      body: body,
    );
    return UserPrivate.fromMap(response);
  }

  @override
  Future<void> deleteUser(String username) async {
    await _store.delete(endpoints.users.user(username));
  }

  @override
  Future<UserPrivate> restoreUser(String username) async {
    final response = await _store.post(endpoints.users.restore(username));
    return UserPrivate.fromMap(response);
  }

  @override
  Future<UserPrivate> submitForReview() async {
    final response = await _store.post(endpoints.users.submitForReview);
    return UserPrivate.fromMap(response);
  }

  @override
  Future<UserInfo> approveUser(
    String username, {
    String? resolutionReason,
  }) async {
    final response = await _store.post(
      endpoints.users.approve(username),
      body: resolutionReason == null
          ? null
          : {'resolutionReason': resolutionReason},
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> blockUser(
    String username, {
    String? resolutionReason,
  }) async {
    final response = await _store.post(
      endpoints.users.block(username),
      body: resolutionReason == null
          ? null
          : {'resolutionReason': resolutionReason},
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> reconsiderUser(String username, String reason) async {
    final response = await _store.post(
      endpoints.users.reconsider(username),
      body: {'reason': reason},
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserPrivate> reapply(
    String username, {
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? dateOfBirthUtc,
    Gender? gender,
    String? phone,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'firstName': ?firstName,
      'middleName': ?middleName,
      'lastName': ?lastName,
      if (dateOfBirthUtc != null)
        'dateOfBirthUtc': dateOfBirthUtc.millisecondsSinceEpoch,
      if (gender != null) 'gender': gender.serverValue,
      'phone': ?phone,
      'email': ?email,
    };
    final response = await _store.patch(
      endpoints.users.reapply(username),
      body: body,
    );
    return UserPrivate.fromMap(response);
  }

  @override
  Future<UserInfo> unblockUser(String username) async {
    final response = await _store.post(endpoints.users.unblock(username));
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> markLeft(String username) async {
    final response = await _store.post(endpoints.users.markLeft(username));
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> reactivateUser(String username) async {
    final response = await _store.post(endpoints.users.reactivate(username));
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> assignRole(String username, String role) async {
    final response = await _store.post(
      endpoints.users.roles(username),
      body: {'role': role},
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<UserInfo> removeRole(String username, String role) async {
    await _store.delete(endpoints.users.removeRole(username, role));
    // The endpoint should return the updated user; fetch it
    return getUserInfo(username);
  }

  @override
  Future<UserInfo> transferSuperAdmin(String username) async {
    final response = await _store.post(
      endpoints.users.transferSuperAdmin(username),
    );
    return UserInfo.fromMap(response);
  }

  @override
  Future<void> hardDeleteUser(String username) async {
    await _store.delete(endpoints.users.hardDelete(username));
  }

  @override
  Future<String> adminResetPassword(String username) async {
    final response = await _store.post(
      endpoints.users.adminResetPassword(username),
    );
    return response['newPassword'] as String;
  }
}
