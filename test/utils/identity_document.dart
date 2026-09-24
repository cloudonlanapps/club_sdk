/// Test helper for the server-side identity-document precondition on
/// `POST /users/me/submit-for-review` introduced by server #142.
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

/// Uploads a tiny placeholder image and attaches it to [username] as an
/// `identity_document` user-media link, satisfying the server precondition
/// for `submit-for-review`.
///
/// The caller must be logged in as [username] (or as an admin acting on
/// that user) when invoked.
Future<void> attachIdentityDocument(
  SecureClient client,
  String username,
) async {
  final media = await client.media.upload(
    fileBytes: _testPngBytes,
    filename: '${username}_id.png',
    contentType: 'image/png',
    preserveOriginal: true,
  );
  await client.userMedia.attach(
    username,
    tag: 'identity_document',
    mediaUuid: media.uuid,
  );
}

/// Minimal valid 1×1 white PNG (67 bytes).
const List<int> _testPngBytes = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xE2,
  0x21,
  0xBC,
  0x33,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
