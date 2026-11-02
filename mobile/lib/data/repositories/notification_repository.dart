import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  /// Get user notifications using RPC function
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_notifications',
        params: {'user_id_param': userId},
      );

      if (response == null) return [];

      return (response as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Get unread notification count using RPC function
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_unread_notification_count',
        params: {'user_id_param': userId},
      );

      return response as int? ?? 0;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase.from('notification_reads').upsert(
        {
          'notification_id': notificationId,
          'user_id': userId,
        },
        onConflict: 'notification_id,user_id',
      );
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      // Get all unread notifications
      final notifications = await getUserNotifications(userId);
      final unreadNotifications = notifications.where((n) => !n.isRead).toList();

      // Mark each as read
      for (final notification in unreadNotifications) {
        await markAsRead(notification.id, userId);
      }
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Delete notification (admin only)
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Delete notification_reads first
      await _supabase
          .from('notification_reads')
          .delete()
          .eq('notification_id', notificationId);

      // Then delete notification
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Clear all notifications (admin only)
  Future<void> clearAllNotifications(String userId) async {
    try {
      final notifications = await getUserNotifications(userId);

      for (final notification in notifications) {
        await deleteNotification(notification.id);
      }
    } catch (e) {
      throw Exception('Failed to clear all notifications: $e');
    }
  }

  /// Create notification (for testing or manual creation)
  Future<void> createNotification({
    required String title,
    required String body,
    String? recipientRole,
    String? recipientUserId,
    String? url,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'title': title,
        'body': body,
        if (recipientRole != null) 'recipient_role': recipientRole,
        if (recipientUserId != null) 'recipient_user_id': recipientUserId,
        if (url != null) 'url': url,
        if (type != null) 'type': type,
        if (data != null) 'data': data,
      });
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }
}
