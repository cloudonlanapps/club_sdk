/// Test helper for the occurrence's own optimistic lock (club_server#430,
/// SDK #1): every occurrence change — reschedule, cancel, undo-cancel, and a
/// one-off's drop and reinstate — sends the version the caller last loaded.
library;

import 'package:club_sdk_2/club_sdk_2.dart';

/// The current version of the occurrence of [eventId] at
/// [occurrenceTimeUtc], read the way an app would before changing it.
///
/// The caller must be logged in as an admin or coach.
Future<int> occurrenceVersion(
  SecureClient client,
  int eventId,
  DateTime occurrenceTimeUtc,
) async => (await client.occurrences.getOccurrence(
  eventId,
  occurrenceTimeUtc,
)).version;
