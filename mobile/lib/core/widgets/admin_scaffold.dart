import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/tenant_subscription_provider.dart';
import '../theme/app_colors.dart';
import 'subscription_grace_banner.dart';
import 'subscription_lock_overlay.dart';

class AdminScaffold extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AdminScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  int _getCurrentIndex() {
    if (currentRoute.startsWith('/admin/dashboard')) return 0;
    if (currentRoute.startsWith('/admin/customers')) return 1;
    if (currentRoute.startsWith('/admin/invoices')) return 2;
    if (currentRoute.startsWith('/admin/expenses')) return 3;
    if (currentRoute.startsWith('/admin/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Periksa status langganan tenant (SaaS)
    final subAsync = ref.watch(tenantSubscriptionProvider);
    final subscription = subAsync.valueOrNull;

    // 1. Kunci Total (Hard Lock): Hari ke-4 ke atas ATAU status suspended
    if (subscription != null && subscription.isHardLocked) {
      return SubscriptionLockOverlay(subscription: subscription);
    }

    final currentIndex = _getCurrentIndex();
    final isGracePeriod = subscription != null && subscription.isGracePeriod;

    return Scaffold(
      body: Column(
        children: [
          // Banner Peringatan Masa Tenggang (Hari H s/d Hari ke-3)
          if (isGracePeriod)
            SubscriptionGraceBanner(subscription: subscription),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9F8FB),
          border: Border(
            top: BorderSide(color: Color(0xFFEAE8F3), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Dashboard
                _buildNavItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Dasbor',
                  isActive: currentIndex == 0,
                  onTap: () => context.go('/admin/dashboard'),
                ),
                // Pelanggan
                _buildNavItem(
                  context: context,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Pelanggan',
                  isActive: currentIndex == 1,
                  onTap: () => context.go('/admin/customers'),
                ),
                // FAB Tagihan (center)
                _buildFabItem(
                  context: context,
                  isActive: currentIndex == 2,
                  onTap: () => context.go('/admin/invoices'),
                ),
                // Pengeluaran
                _buildNavItem(
                  context: context,
                  icon: Icons.attach_money_outlined,
                  activeIcon: Icons.attach_money,
                  label: 'Pengeluaran',
                  isActive: currentIndex == 3,
                  onTap: () => context.go('/admin/expenses'),
                ),
                // Profil
                _buildNavItem(
                  context: context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  isActive: currentIndex == 4,
                  onTap: () => context.go('/admin/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? AppColors.primary : const Color(0xFF625095);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabItem({
    required BuildContext context,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, -16),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667EEA), Color(0xFF5324E0)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66667EEA),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
