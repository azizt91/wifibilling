import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

// Notification Model
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? url;
  final String? type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      url: json['url'] as String?,
      type: json['type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Notification Repository
class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  Future<List<NotificationModel>> getNotifications(String userId) async {
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
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      // Use RPC function for better performance
      final result = await _supabase.rpc('get_unread_notification_count', params: {
        'user_id_param': userId,
      });
      return result as int? ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      // Use RPC function for better security
      final result = await _supabase.rpc('mark_notification_read', params: {
        'notification_id_param': notificationId,
        'user_id_param': userId,
      });
      return result == true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String userId) async {
    try {
      final notifications = await getNotifications(userId);
      final unreadIds = notifications.where((n) => !n.isRead).map((n) => n.id).toList();

      if (unreadIds.isEmpty) return true;

      final records = unreadIds.map((id) => {
        'notification_id': id,
        'user_id': userId,
      }).toList();

      await _supabase.from('notification_reads').upsert(records);
      return true;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      // Delete read records first
      await _supabase
          .from('notification_reads')
          .delete()
          .eq('notification_id', notificationId);

      // Then delete notification
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  Future<bool> deleteAllNotifications(String userId) async {
    try {
      // Get all notifications for this user
      final notifications = await getNotifications(userId);
      if (notifications.isEmpty) return true;

      final notificationIds = notifications.map((n) => n.id).toList();

      // Delete all read records for these notifications
      await _supabase
          .from('notification_reads')
          .delete()
          .inFilter('notification_id', notificationIds);

      // Delete notifications that are for this user or for ADMIN role
      await _supabase
          .from('notifications')
          .delete()
          .or('recipient_user_id.eq.$userId,and(recipient_role.eq.ADMIN,recipient_user_id.is.null)');

      return true;
    } catch (e) {
      print('Error deleting all notifications: $e');
      return false;
    }
  }
}

// Providers
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(supabaseClientProvider));
});

final notificationsProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];

  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications(user.id);
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0;

  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadCount(user.id);
});
