import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// A contact block as a deployment stores it: plain and translated values
/// mixed, and a key this model does not know.
Map<String, dynamic> storedBlock() => {
  'phoneNumber': '+911234567890',
  'email': 'hello@myexampleclub.com',
  'whatsappNumber': '+919876543210',
  'whatsappMessage': {'default': 'Hi!', 'mr': 'नमस्कार!'},
  'emailSubject': 'Enquiry',
  'tagline': {'default': 'Skate with us', 'hi': 'हमारे साथ स्केट करें'},
  'address': '1 Rink Road',
  'addressLine2': 'Near the park',
  'city': 'Example City',
  'state': 'Example State',
  'postalCode': '400001',
  'instagramUrl': 'https://instagram.com/myexampleclub',
  'openingHours': 'Mon–Fri',
};

void main() {
  group('ClubContactDetails', () {
    test('Issue 90: fromMap reads every field of a stored block', () {
      final contact = ClubContactDetails.fromMap(storedBlock());
      expect(contact.phoneNumber, '+911234567890');
      expect(contact.email, 'hello@myexampleclub.com');
      expect(contact.whatsappNumber, '+919876543210');
      expect(
        contact.whatsappMessage,
        const LocalizedText('Hi!', {'mr': 'नमस्कार!'}),
      );
      expect(contact.emailSubject, const LocalizedText('Enquiry'));
      expect(contact.tagline!.resolve('hi'), 'हमारे साथ स्केट करें');
      expect(contact.address, const LocalizedText('1 Rink Road'));
      expect(contact.addressLine2, const LocalizedText('Near the park'));
      expect(contact.city, const LocalizedText('Example City'));
      expect(contact.state, const LocalizedText('Example State'));
      expect(contact.postalCode, '400001');
      expect(contact.instagramUrl, 'https://instagram.com/myexampleclub');
    });

    test('Issue 90: fromMap keeps unknown keys in extra', () {
      final contact = ClubContactDetails.fromMap(storedBlock());
      expect(contact.extra, {'openingHours': 'Mon–Fri'});
    });

    test('Issue 90: toMap writes back exactly what was stored', () {
      final stored = storedBlock();
      expect(ClubContactDetails.fromMap(stored).toMap(), stored);
    });

    test('Issue 90: an empty block reads with every field absent', () {
      final contact = ClubContactDetails.fromMap(const {});
      expect(contact, const ClubContactDetails());
      expect(contact.toMap(), isEmpty);
    });

    test('Issue 90: a wrongly-typed value reads as absent and is carried '
        'through unchanged', () {
      final contact = ClubContactDetails.fromMap(const {
        'phoneNumber': 12345,
        'tagline': {'mr': 'no default'},
      });
      expect(contact.phoneNumber, isNull);
      expect(contact.tagline, isNull);
      expect(contact.toMap(), {
        'phoneNumber': 12345,
        'tagline': {'mr': 'no default'},
      });
    });

    test('Issue 90: a field that is set replaces the unreadable stored '
        'value', () {
      final contact = ClubContactDetails.fromMap(const {
        'phoneNumber': 12345,
      }).copyWith(phoneNumber: () => '+911111111111');
      expect(contact.toMap(), {'phoneNumber': '+911111111111'});
    });

    test('Issue 90: toMap leaves out null fields', () {
      const contact = ClubContactDetails(email: 'a@myexampleclub.com');
      expect(contact.toMap(), {'email': 'a@myexampleclub.com'});
    });

    test('Issue 90: copyWith clears a field through its ValueGetter', () {
      final contact = ClubContactDetails.fromMap(storedBlock());
      final cleared = contact.copyWith(
        instagramUrl: () => null,
        tagline: () => null,
      );
      expect(cleared.instagramUrl, isNull);
      expect(cleared.tagline, isNull);
      expect(cleared.toMap().containsKey('instagramUrl'), isFalse);
      expect(cleared.toMap().containsKey('tagline'), isFalse);
      expect(cleared.email, contact.email);
    });

    test('Issue 90: toJson and fromJson round-trip', () {
      final contact = ClubContactDetails.fromMap(storedBlock());
      expect(ClubContactDetails.fromJson(contact.toJson()), contact);
    });

    test('Issue 90: equality and hashCode include extra', () {
      final a = ClubContactDetails.fromMap(storedBlock());
      final b = ClubContactDetails.fromMap(storedBlock());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(extra: {})));
    });
  });
}
