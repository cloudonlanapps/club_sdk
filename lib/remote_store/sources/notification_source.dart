import '../../sdk/interfaces/notification.dart';
import '../../sdk/models/notification.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [NotificationSource] using HTTP API.
class RemoteNotificationSource implements NotificationSource {
  RemoteNotificationSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<AppNotification>> getNotifications({
    int offset = 0,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      'unreadOnly': unreadOnly.toString(),
    };
    final response = await _store.get(
      endpoints.notifications.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(
      response,
      AppNotification.fromMap,
    );
  }

  @override
  Future<PaginatedList<AppNotification>> listPendingActions({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.notifications.pendingActions,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, AppNotification.fromMap);
  }

  @override
  Future<void> markRead(int id) async {
    await _store.postVoid(endpoints.notifications.markRead(id));
  }

  @override
  Future<void> markAllRead() async {
    await _store.postVoid(endpoints.notifications.markAllRead);
  }

  @override
  Future<NotificationPref> getPreferences() async {
    final response = await _store.get(endpoints.notifications.preferences);
    return NotificationPref.fromMap(response);
  }

  @override
  Future<NotificationPref> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
  }) async {
    final response = await _store.patch(
      endpoints.notifications.preferences,
      body: {
        'emailEnabled': ?emailEnabled,
        'pushEnabled': ?pushEnabled,
        'smsEnabled': ?smsEnabled,
      },
    );
    return NotificationPref.fromMap(response);
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _store.get(endpoints.notifications.unreadCount);
    return response['count'] as int? ?? 0;
  }

  @override
  Future<AppNotification> createNotification({
    required String username,
    required String type,
    required String channel,
    required Map<String, dynamic> payload,
    PendingActionType? pendingActionType,
    int? pendingActionId,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'type': type,
      'channel': channel,
      'payload': payload,
      if (pendingActionType != null)
        'pendingActionType': pendingActionType.wireName,
      'pendingActionId': ?pendingActionId,
    };
    final response = await _store.post(
      endpoints.notifications.list,
      body: body,
    );
    return AppNotification.fromMap(response);
  }

  @override
  Future<void> deleteNotification(int id) async {
    await _store.delete(endpoints.notifications.notification(id));
  }
}
