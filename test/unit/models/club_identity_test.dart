import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// The `club_info` document as a deployment stores it, including keys this
/// model does not know.
Map<String, dynamic> storedDocument() => {
  'name': 'My Example Club',
  'shortName': 'MEC',
  'inquiryEmail': 'inquiries@myexampleclub.com',
  'contact': {
    'phoneNumber': '+911234567890',
    'tagline': {'default': 'Skate with us', 'mr': 'आमच्यासोबत स्केट करा'},
    'socials': ['x'],
  },
  'story': {'default': 'Founded on a frozen pond.'},
};

void main() {
  group('ClubIdentity', () {
    test('Issue 90: the preference key is club_info', () {
      expect(ClubIdentity.preferenceKey, 'club_info');
    });

    test('Issue 90: fromMap reads the top-level fields and the contact '
        'block', () {
      final identity = ClubIdentity.fromMap(storedDocument());
      expect(identity.name, 'My Example Club');
      expect(identity.shortName, 'MEC');
      expect(identity.inquiryEmail, 'inquiries@myexampleclub.com');
      expect(identity.contact!.phoneNumber, '+911234567890');
      expect(identity.contact!.tagline!.defaultValue, 'Skate with us');
      expect(identity.contact!.extra, {
        'socials': ['x'],
      });
    });

    test('Issue 90: fromMap keeps unknown top-level keys in extra', () {
      final identity = ClubIdentity.fromMap(storedDocument());
      expect(identity.extra, {
        'story': {'default': 'Founded on a frozen pond.'},
      });
    });

    test('Issue 90: toMap writes back exactly what was stored', () {
      final stored = storedDocument();
      expect(ClubIdentity.fromMap(stored).toMap(), stored);
    });

    test('Issue 90: an empty document reads with every field absent', () {
      final identity = ClubIdentity.fromMap(const {});
      expect(identity, const ClubIdentity());
      expect(identity.toMap(), isEmpty);
    });

    test('Issue 90: a translated name reads as absent and is carried '
        'through unchanged', () {
      final stored = {
        'name': {'default': 'My Example Club', 'mr': 'माझा क्लब'},
      };
      final identity = ClubIdentity.fromMap(stored);
      expect(identity.name, isNull);
      expect(identity.toMap(), stored);
    });

    test('Issue 90: a contact that is not a map reads as absent and is '
        'carried through unchanged', () {
      final identity = ClubIdentity.fromMap(const {'contact': 'call us'});
      expect(identity.contact, isNull);
      expect(identity.toMap(), {'contact': 'call us'});
    });

    test('Issue 90: an edit keeps the keys the model does not read', () {
      final edited = ClubIdentity.fromMap(storedDocument()).copyWith(
        shortName: () => 'Example',
      );
      final written = edited.toMap();
      expect(written['shortName'], 'Example');
      expect(written['story'], {'default': 'Founded on a frozen pond.'});
      expect((written['contact'] as Map)['socials'], ['x']);
    });

    test('Issue 90: copyWith clears a field through its ValueGetter', () {
      final cleared = ClubIdentity.fromMap(
        storedDocument(),
      ).copyWith(inquiryEmail: () => null, contact: () => null);
      expect(cleared.inquiryEmail, isNull);
      expect(cleared.contact, isNull);
      expect(cleared.toMap().keys, containsAll(['name', 'shortName', 'story']));
      expect(cleared.toMap().containsKey('inquiryEmail'), isFalse);
      expect(cleared.toMap().containsKey('contact'), isFalse);
    });

    test('Issue 90: toJson and fromJson round-trip', () {
      final identity = ClubIdentity.fromMap(storedDocument());
      expect(ClubIdentity.fromJson(identity.toJson()), identity);
    });

    test('Issue 90: equality and hashCode compare deeply', () {
      final a = ClubIdentity.fromMap(storedDocument());
      final b = ClubIdentity.fromMap(storedDocument());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(name: () => 'Other')));
    });

    test('Issue 90: PublicClubInfo.identity reads the public clubInfo', () {
      final info = PublicClubInfo(clubInfo: storedDocument());
      expect(info.identity, ClubIdentity.fromMap(storedDocument()));
    });

    test('Issue 90: an unconfigured PublicClubInfo has an empty identity', () {
      expect(const PublicClubInfo().identity, const ClubIdentity());
    });
  });
}
