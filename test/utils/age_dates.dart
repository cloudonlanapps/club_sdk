/// Dates of birth counted back from today, for tests of age-based
/// eligibility (club_server#16).
///
/// An age band's window moves forward each day, so a test that fixes a date
/// of birth would drift out of its band. Pick ages well inside or outside a
/// band, by months, not days: the club's calendar day (`CLUB_TIMEZONE`) can
/// be a day ahead of UTC, and a short month can shift the result by a few
/// days.
library;

/// The date of birth of someone [years] and [months] old today, at UTC
/// midnight.
DateTime bornAgo({required int years, int months = 0}) {
  final today = DateTime.now().toUtc();
  return DateTime.utc(today.year - years, today.month - months, today.day);
}
