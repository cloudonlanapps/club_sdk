import 'package:meta/meta.dart';

@immutable
class OccurrenceEndpoints {
  const OccurrenceEndpoints();

  String get list => '/events/occurrences';
  String occurrence(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr';
  String reschedule(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/reschedule';
  String cancel(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/cancel';
  String undoCancel(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/undo-cancel';
}
