/// Test helper for the server-side identity-document precondition on
/// `POST /users/me/submit-for-review` introduced by server #142. The
/// precondition applies only while the deployment requires identity
/// verification (`Capabilities.identityVerification`, #2).
///
/// The server rejects `submit-for-review` with 422 `IDENTITY_DOCUMENT_REQUIRED`
/// unless the caller has a live `user_media` link tagged `identity_document`
/// (a v2 media row that is not soft-deleted). Tests must therefore upload
/// a media row and attach it to the user before invoking submit-for-review.
///
/// The matching server-side helper is `server/tests/helpers.py::attach_identity_document`,
/// which bypasses the upload pipeline by inserting rows directly via the
/// database session. Over HTTP we go through the public API: upload via
/// `client.media.upload`, then link via `client.userMedia.attach`.
library;

import 'package:club_sdk_2/club_sdk_2.dart';
import 'test_png.dart';

/// Uploads a tiny placeholder image and attaches it to [username] as an
/// `identity_document` user-media link, satisfying the server precondition
/// for `submit-for-review`. Like the app, it restricts the document to the
/// user and admins rather than leaving it public.
///
/// The caller must be logged in as [username] (or as an admin acting on
/// that user) when invoked.
Future<void> attachIdentityDocument(
  SecureClient client,
  String username,
) async {
  final media = await client.media.upload(
    fileBytes: testPngBytes,
    filename: '${username}_id.png',
    contentType: 'image/png',
    preserveOriginal: true,
    accessRoles: const ['self', 'admin'],
  );
  await client.userMedia.attach(
    username,
    tag: 'identity_document',
    mediaUuid: media.uuid,
  );
}

/// Takes a freshly [registered] user to `pending`, then returns the session
/// to the admin.
///
/// With identity verification on, `register` leaves the user `registered`:
/// log in as them, attach an identity document and submit for review. With
/// it off (club_server#428, #2), `register` already returned them `pending`
/// and submit-for-review would be refused, so only the admin login happens.
/// Either way [client] ends logged in as the admin.
Future<void> submitForReviewIfRequired({
  required SecureClient client,
  required UserInfo registered,
  required String password,
  required String adminUsername,
  required String adminPassword,
}) async {
  if (registered.status == UserStatus.registered) {
    // login() replaces the current session, so no explicit logout is needed
    // here. A registered user cannot logout (server returns 403
    // ACCOUNT_NOT_ACTIVE), so we just swap sessions in-place.
    await client.auth.login(registered.username, password);
    await attachIdentityDocument(client, registered.username);
    await client.users.submitForReview();
  }
  await client.auth.login(adminUsername, adminPassword);
}
