import '../models/notification.dart';
import '../models/pagination.dart';

/// Interface for notification operations.
abstract interface class NotificationSource {
  /// Get notifications for the current user.
  Future<PaginatedList<AppNotification>> getNotifications({
    int offset = 0,
    int limit = 20,
    bool unreadOnly = false,
  });

  /// Get the current user's actionable notifications whose linked source row
  /// is still unresolved. The server auto-dismisses entries once the source
  /// row reaches a terminal state, so the returned list reflects only items
  /// that still need attention.
  Future<PaginatedList<AppNotification>> listPendingActions({
    int offset = 0,
    int limit = 20,
  });

  /// Mark a notification as read.
  Future<void> markRead(int id);

  /// Mark all notifications as read.
  Future<void> markAllRead();

  /// Get notification preferences for the current user.
  Future<NotificationPref> getPreferences();

  /// Update notification preferences.
  Future<NotificationPref> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
  });

  /// Get the count of unread notifications for the current user.
  Future<int> getUnreadCount();

  /// Create a notification for a user.
  /// Only admins can create notifications.
  ///
  /// [payload] follows the server's `{v, type, data}` envelope and carries all
  /// display content. [pendingActionType] / [pendingActionId] mark the row as
  /// server for sorting / dismissal heuristics.
  Future<AppNotification> createNotification({
    required String username,
    required String type,
    required String channel,
    required Map<String, dynamic> payload,
    PendingActionType? pendingActionType,
    int? pendingActionId,
    String? pendingActionKey,
  });

  /// Soft delete a notification.
  Future<void> deleteNotification(int id);
}
