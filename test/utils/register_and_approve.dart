/// Test helper that walks a user through the full
/// `register → submitForReview → approveUser` lifecycle introduced by
/// server #120 / SDK #374.
///
/// On a deployment with identity verification off (club_server#428, #2),
/// `register` already returns the user `pending`, so the document upload and
/// submit-for-review are skipped and the helper goes straight to approval.
///
/// Caller must be logged in as an admin (or sudo) when invoked; the helper
/// logs the admin out to act as the new user for `submitForReview`, then
/// logs the admin back in before calling `approveUser`. The admin session
/// is the session that is active when the helper returns.
library;

import 'package:club_sdk_2/club_sdk_2.dart';

import 'identity_document.dart';

/// Registers a new user, submits them for review (as that user), and
/// approves them (as the admin).
///
/// Returns the approved [UserInfo].
Future<UserInfo> registerAndApprove({
  required SecureClient client,
  required String adminUsername,
  required String adminPassword,
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
  final registered = await client.auth.register(
    username: username,
    email: email,
    password: password,
    phone: phone,
    dateOfBirthUtc: dateOfBirthUtc,
    gender: gender,
    firstName: firstName,
    middleName: middleName,
    lastName: lastName,
  );
  await submitForReviewIfRequired(
    client: client,
    registered: registered,
    password: password,
    adminUsername: adminUsername,
    adminPassword: adminPassword,
  );
  return client.users.approveUser(username);
}
