import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../data/providers/notification_provider.dart';
import '../../../../../data/providers/auth_provider.dart';

class AdminNotificationsPage extends ConsumerStatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  ConsumerState<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends ConsumerState<AdminNotificationsPage> {
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    // Tandai semua notifikasi sebagai sudah dibaca saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsReadOnOpen();
    });
  }

  Future<void> _markAllAsReadOnOpen() async {
    if (_hasMarkedAsRead) return; // Hindari pemanggilan berulang
    
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _hasMarkedAsRead = true;
      await ref.read(notificationRepositoryProvider).markAllAsRead(user.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: notifications.when(
                data: (data) => _buildNotificationList(data),
                loading: () => _buildLoadingSkeleton(),
                error: (e, _) => _buildError(e.toString()),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
              ),
              const Expanded(
                child: Text(
                  'Pusat Notifikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF110E1B),
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada notifikasi saat ini',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (_, index) => _buildNotificationItem(notifications[index]),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? const Color(0xFFE5E7EB) : const Color(0xFF3B82F6),
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (!notification.isRead) {
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user != null) {
                await ref.read(notificationRepositoryProvider).markAsRead(notification.id, user.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
              }
            }
            // Navigate to URL if exists
            if (notification.url != null && notification.url!.isNotEmpty) {
              // Handle navigation based on URL
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: notification.isRead ? const Color(0xFFF3F4F6) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: notification.isRead ? const Color(0xFF6B7280) : const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                          color: const Color(0xFF110E1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.createdAt != null 
                            ? dateFormat.format(notification.createdAt!.toLocal()) 
                            : '-',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                // Actions
                Column(
                  children: [
                    if (!notification.isRead)
                      _buildActionButton(
                        icon: Icons.check,
                        color: const Color(0xFF3B82F6),
                        bgColor: const Color(0xFFDBEAFE),
                        onTap: () async {
                          final user = ref.read(currentUserProvider).valueOrNull;
                          if (user != null) {
                            await ref.read(notificationRepositoryProvider).markAsRead(notification.id, user.id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationCountProvider);
                          }
                        },
                      ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFFEE2E2),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Notifikasi'),
                            content: const Text('Yakin ingin menghapus notifikasi ini?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(notificationRepositoryProvider).deleteNotification(notification.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadNotificationCountProvider);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }


  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Semua'),
                      content: const Text('PERHATIAN: Ini akan menghapus semua notifikasi secara permanen!'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final user = ref.read(currentUserProvider).valueOrNull;
                    if (user != null) {
                      final success = await ref.read(notificationRepositoryProvider).deleteAllNotifications(user.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Semua notifikasi berhasil dihapus' : 'Gagal menghapus notifikasi')),
                        );
                      }
                    }
                  }
                },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFFEE2E2)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Hapus Semua', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text('Gagal memuat notifikasi', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
