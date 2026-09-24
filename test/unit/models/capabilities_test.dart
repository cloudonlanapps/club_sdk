import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/endpoints/capabilities.dart';
import 'package:test/test.dart';

/// Issue 15: capability discovery and the module-off exception, the
/// foundation credits (#14), evaluations (#15) and marketing (#22) share.
void main() {
  group('Issue 15: Capabilities', () {
    test('Issue 15: fromMap reads the three modules, defaulting to off', () {
      final all = Capabilities.fromMap(const {
        'creditSystem': true,
        'evaluations': true,
        'eventMarketing': true,
      });
      expect(all.creditSystem, isTrue);
      expect(all.evaluations, isTrue);
      expect(all.eventMarketing, isTrue);
      final old = Capabilities.fromMap(const {'creditSystem': false});
      expect(old.evaluations, isFalse);
      expect(old.eventMarketing, isFalse);
    });

    test('Issue 15: round-trip, copyWith, equality', () {
      const c = Capabilities(evaluations: true);
      expect(Capabilities.fromMap(c.toMap()), c);
      expect(Capabilities.fromJson(c.toJson()), c);
      expect(c.copyWith(creditSystem: true), isNot(c));
      expect(c.hashCode, const Capabilities(evaluations: true).hashCode);
    });

    test('Issue 2: identityVerification reads true when the server '
        'omits it', () {
      // A server that predates the field always required verification.
      final old = Capabilities.fromMap(const {'creditSystem': false});
      expect(old.identityVerification, isTrue);
      expect(const Capabilities().identityVerification, isTrue);
    });

    test('Issue 2: identityVerification reads the server value', () {
      expect(
        Capabilities.fromMap(const {
          'identityVerification': false,
        }).identityVerification,
        isFalse,
      );
      expect(
        Capabilities.fromMap(const {
          'identityVerification': true,
        }).identityVerification,
        isTrue,
      );
    });

    test('Issue 2: identityVerification round-trips and takes part in '
        'equality', () {
      const off = Capabilities(identityVerification: false);
      expect(off.toMap()['identityVerification'], isFalse);
      expect(Capabilities.fromMap(off.toMap()), off);
      expect(off, isNot(const Capabilities()));
      expect(off.copyWith(identityVerification: true), const Capabilities());
    });

    test('Issue 15: endpoint', () {
      expect(const CapabilitiesEndpoints().capabilities, '/capabilities');
    });
  });

  group('Issue 15: ModuleDisabledException', () {
    for (final code in const [
      'CREDIT_SYSTEM_DISABLED',
      'EVALUATIONS_DISABLED',
      'EVENT_MARKETING_DISABLED',
    ]) {
      test('Issue 15: 503 $code maps to ModuleDisabledException', () {
        final exc = mapHttpError(503, {
          'detail': {'code': code, 'message': 'off'},
        });
        expect(exc, isA<ModuleDisabledException>());
        expect(exc.statusCode, 503);
        expect(exc.code, code);
      });
    }

    test('Issue 15: other 503s stay plain ServerException', () {
      final exc = mapHttpError(503, const {
        'detail': {'code': 'UNEXPECTED_ERROR', 'message': 'm'},
      });
      expect(exc, isNot(isA<ModuleDisabledException>()));
    });
  });
}
