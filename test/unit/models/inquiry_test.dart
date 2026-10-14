import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 22: an inquiry's message is optional (club_server#41).
Map<String, dynamic> _row({Object? message = 'Hello'}) => {
  'id': 3,
  'kind': 'interest',
  'name': 'test_person',
  'email': 'test_person@test.com',
  'phone': null,
  'message': message,
  'extra': {'ageGroup': 'U12'},
  'createdAtUtc': 1700000000000,
  'handledAt': null,
  'handledBy': null,
};

void main() {
  group('Inquiry.message', () {
    test('Issue 22: reads an inquiry whose message is null', () {
      final inquiry = Inquiry.fromMap(_row(message: null));

      expect(inquiry.message, isNull);
      expect(inquiry.kind, InquiryKind.interest);
    });

    test('Issue 22: reads an inquiry that has no message key', () {
      final inquiry = Inquiry.fromMap(_row()..remove('message'));

      expect(inquiry.message, isNull);
    });

    test('Issue 22: a missing message survives a map round trip', () {
      final inquiry = Inquiry.fromMap(_row(message: null));

      expect(Inquiry.fromMap(inquiry.toMap()), inquiry);
    });

    test('Issue 22: copyWith clears the message through its getter', () {
      final inquiry = Inquiry.fromMap(_row());

      final cleared = inquiry.copyWith(message: () => null);

      expect(cleared.message, isNull);
      expect(inquiry.copyWith().message, 'Hello');
      expect(cleared, isNot(inquiry));
    });
  });
}
