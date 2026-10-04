import 'package:club_sdk_2/remote_store/endpoints/notification.dart';
import 'package:test/test.dart';

void main() {
  const ep = NotificationEndpoints();

  group('NotificationEndpoints', () {
    test('list', () => expect(ep.list, '/notifications'));
    test(
      'markRead',
      () => expect(ep.markRead(1), '/notifications/by_id/1/read'),
    );
    test(
      'markAllRead',
      () => expect(ep.markAllRead, '/notifications/read-all'),
    );
    test(
      'preferences',
      () => expect(ep.preferences, '/notifications/preferences'),
    );
    test(
      'unreadCount',
      () => expect(ep.unreadCount, '/notifications/unread-count'),
    );
    test(
      'notification',
      () => expect(ep.notification(1), '/notifications/by_id/1'),
    );
  });
}
