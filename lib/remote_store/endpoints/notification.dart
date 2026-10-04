import 'package:meta/meta.dart';

@immutable
class NotificationEndpoints {
  const NotificationEndpoints();

  String get list => '/notifications';
  String get pendingActions => '/notifications/pending-actions';
  String markRead(int id) => '/notifications/by_id/$id/read';
  String get markAllRead => '/notifications/read-all';
  String get preferences => '/notifications/preferences';
  String get unreadCount => '/notifications/unread-count';
  String notification(int id) => '/notifications/by_id/$id';
}
