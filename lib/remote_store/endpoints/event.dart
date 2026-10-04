import 'package:meta/meta.dart';

@immutable
class EventEndpoints {
  const EventEndpoints();

  String get checkConflict => '/events/check-conflict';
  String checkUserConflicts(int eventId) =>
      '/events/by_id/$eventId/check-user-conflicts';
  String get list => '/events';
  String get deleted => '/events/deleted';
  String event(int eventId) => '/events/by_id/$eventId';
  String correction(int eventId) => '/events/by_id/$eventId/correction';
  String future(int eventId) => '/events/by_id/$eventId/future';
  String reschedule(int eventId) => '/events/by_id/$eventId/reschedule';
  String cancel(int eventId) => '/events/by_id/$eventId/cancel';
  String undoCancel(int eventId) => '/events/by_id/$eventId/undo-cancel';
  String schedules(int eventId) => '/events/by_id/$eventId/schedules';
  String terminate(int eventId) => '/events/by_id/$eventId/terminate';
  String extend(int eventId) => '/events/by_id/$eventId/extend';
  String extendIndefinitely(int eventId) =>
      '/events/by_id/$eventId/extend-indefinitely';
  String drop(int eventId) => '/events/by_id/$eventId/drop';
  String reinstate(int eventId) => '/events/by_id/$eventId/reinstate';
  String restore(int eventId) => '/events/by_id/$eventId/restore';
  String hardDelete(int eventId) => '/events/by_id/$eventId/hard';
  String eligible(int eventId) => '/events/by_id/$eventId/eligible';
}
