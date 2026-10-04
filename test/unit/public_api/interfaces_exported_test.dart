import 'dart:io';

// Only the public entry points: a type below that is not exported through
// them fails to compile.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

/// Issue 10: every `*Source` interface can be named through the public entry
/// points, so a caller can fake or wrap any source without importing from
/// inside the package.
void main() {
  // Names the compiler must resolve through the barrels alone.
  const exported = <Type>[
    AdminSource,
    AttendanceSource,
    AuditLogSource,
    AuthSource,
    BroadcastSource,
    CapabilitiesSource,
    CreditSource,
    EnrollmentSource,
    EvaluationMediaSource,
    EvaluationSource,
    EventMarketingSource,
    EventMediaSource,
    EventSource,
    GroupMediaSource,
    GroupSource,
    InquirySource,
    MediaSource,
    MyCreditsSource,
    MyEvaluationsSource,
    MyEventsSource,
    MyGroupsSource,
    NotificationSource,
    OccurrenceSource,
    OwnerMediaSource,
    PublicSource,
    UserMediaSource,
    UserSource,
    VenueMediaSource,
    VenueSource,
  ];

  test('Issue 10: every interface in lib/sdk/interfaces is exported', () {
    final declared = <String>{};
    final pattern = RegExp(r'abstract interface class (\w+)');
    for (final f in Directory('lib/sdk/interfaces').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      declared.addAll(
        pattern.allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    expect(declared, isNotEmpty, reason: 'found no interfaces to check');
    expect(
      // A generic interface prints with its type argument
      // (`OwnerMediaSource<dynamic>`); compare bare class names.
      exported.map((t) => t.toString().split('<').first).toSet(),
      declared,
      reason:
          'a new interface must be exported from club_sdk_2.dart and '
          'listed here',
    );
  });

  test('Issue 10: SecureClient is built from the exported interfaces', () {
    // A compile-time link to the client the interfaces serve.
    expect(SecureClient, isNotNull);
    expect(createRemoteSecureClient, isNotNull);
  });
}
