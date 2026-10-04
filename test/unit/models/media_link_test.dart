import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

Map<String, dynamic> linkPayload({Object? ownerDeleted = _absent}) => {
  'tag': 'photos',
  'metadata': null,
  'media': {
    'uuid': 'u1',
    'mimeType': 'image/webp',
    'filename': 'u1abcdef_team.webp',
  },
  'createdAtUtc': 1000,
  'updatedAtUtc': 2000,
  if (!identical(ownerDeleted, _absent)) 'ownerDeleted': ownerDeleted,
};

Map<String, dynamic> reversePayload({Object? ownerDeleted = _absent}) => {
  'ownerType': 'group',
  'ownerId': 7,
  'tag': 'photos',
  'metadata': null,
  'createdAtUtc': 1000,
  'updatedAtUtc': 2000,
  if (!identical(ownerDeleted, _absent)) 'ownerDeleted': ownerDeleted,
};

Map<String, dynamic> crossPayload({Object? ownerDeleted = _absent}) => {
  'mediaUuid': 'u1',
  'ownerType': 'venue',
  'ownerId': 3,
  'tag': 'photos',
  'metadata': null,
  'mediaType': 'image',
  'createdAtUtc': 1000,
  if (!identical(ownerDeleted, _absent)) 'ownerDeleted': ownerDeleted,
};

const Object _absent = Object();

void main() {
  group('MediaLink', () {
    test('fromMap reads a link without ownerDeleted as a live owner', () {
      final link = MediaLink.fromMap(linkPayload());
      expect(link.ownerDeleted, isFalse);
      expect(link.tag, 'photos');
      expect(link.mediaUuid, 'u1');
    });

    test('fromMap reads ownerDeleted: null as a live owner', () {
      final link = MediaLink.fromMap(linkPayload(ownerDeleted: null));
      expect(link.ownerDeleted, isFalse);
    });

    test('club_server#517: fromMap reads ownerDeleted: true', () {
      final link = MediaLink.fromMap(linkPayload(ownerDeleted: true));
      expect(link.ownerDeleted, isTrue);
    });

    test('toMap round-trips ownerDeleted', () {
      final link = MediaLink.fromMap(linkPayload(ownerDeleted: true));
      final again = MediaLink.fromMap(link.toMap());
      expect(again, link);
      expect(again.ownerDeleted, isTrue);
    });

    test('== and hashCode tell a deleted owner from a live one', () {
      final live = MediaLink.fromMap(linkPayload(ownerDeleted: false));
      final deleted = MediaLink.fromMap(linkPayload(ownerDeleted: true));
      expect(live == deleted, isFalse);
      expect(live, MediaLink.fromMap(linkPayload()));
      expect(live.hashCode, MediaLink.fromMap(linkPayload()).hashCode);
    });
  });

  group('MediaLinkReverseEntry', () {
    test('fromMap reads an entry without ownerDeleted as a live owner', () {
      final entry = MediaLinkReverseEntry.fromMap(reversePayload());
      expect(entry.ownerDeleted, isFalse);
      expect(entry.ownerType, MediaLinkOwnerType.group);
      expect(entry.ownerId, '7');
    });

    test('club_server#517: fromMap reads ownerDeleted: true', () {
      final entry = MediaLinkReverseEntry.fromMap(
        reversePayload(ownerDeleted: true),
      );
      expect(entry.ownerDeleted, isTrue);
    });

    test('== and hashCode tell a deleted owner from a live one', () {
      final live = MediaLinkReverseEntry.fromMap(reversePayload());
      final deleted = MediaLinkReverseEntry.fromMap(
        reversePayload(ownerDeleted: true),
      );
      expect(live == deleted, isFalse);
      expect(live, MediaLinkReverseEntry.fromMap(reversePayload()));
      expect(
        live.hashCode,
        MediaLinkReverseEntry.fromMap(reversePayload()).hashCode,
      );
    });
  });

  group('MediaLinkCrossEntry', () {
    test('fromMap reads an entry without ownerDeleted as a live owner', () {
      final entry = MediaLinkCrossEntry.fromMap(crossPayload());
      expect(entry.ownerDeleted, isFalse);
      expect(entry.ownerType, MediaLinkOwnerType.venue);
      expect(entry.mediaUuid, 'u1');
    });

    test('club_server#517: fromMap reads ownerDeleted: true', () {
      final entry = MediaLinkCrossEntry.fromMap(
        crossPayload(ownerDeleted: true),
      );
      expect(entry.ownerDeleted, isTrue);
    });

    test('== and hashCode tell a deleted owner from a live one', () {
      final live = MediaLinkCrossEntry.fromMap(crossPayload());
      final deleted = MediaLinkCrossEntry.fromMap(
        crossPayload(ownerDeleted: true),
      );
      expect(live == deleted, isFalse);
      expect(live, MediaLinkCrossEntry.fromMap(crossPayload()));
      expect(
        live.hashCode,
        MediaLinkCrossEntry.fromMap(crossPayload()).hashCode,
      );
    });
  });
}
