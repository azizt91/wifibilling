import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/customer/dashboard/presentation/pages/customer_dashboard_page.dart';
import '../../features/customer/profile/presentation/pages/customer_profile_page.dart';
import '../../features/customer/invoices/presentation/pages/customer_invoices_page.dart';
import '../../features/customer/help/presentation/pages/help_page.dart';
import '../../features/customer/help/presentation/pages/faq_wifi_modem_page.dart';
import '../../features/customer/help/presentation/pages/tutorial_ganti_wifi_page.dart';
import '../../features/customer/wifi/presentation/pages/wifi_settings_page.dart';
import '../../features/customer/payment_info/presentation/pages/payment_info_page.dart';
import '../../features/admin/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/customers/presentation/pages/admin_customers_page.dart';
import '../../features/admin/invoices/presentation/pages/admin_invoices_page.dart';
import '../../features/admin/profile/presentation/pages/admin_profile_page.dart';
import '../../features/admin/expenses/presentation/pages/admin_expenses_page.dart';
import '../../features/admin/settings/presentation/pages/admin_settings_page.dart';
import '../../features/admin/payment_methods/presentation/pages/admin_payment_methods_page.dart';
import '../../features/admin/reports/presentation/pages/admin_reports_page.dart';
import '../../data/providers/auth_provider.dart';
import '../widgets/customer_scaffold.dart';
import '../widgets/admin_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Wait for auth state to load
      if (authState.isLoading) {
        return '/splash';
      }

      final user = authState.value;
      final isLoggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';

      print('🔵 [Router] Redirect check:');
      print('  - Location: ${state.matchedLocation}');
      print('  - User: ${user?.fullName ?? "null"}');
      print('  - Role: ${user?.role ?? "null"}');
      print('  - isAdmin: ${user?.isAdmin ?? false}');

      // If not logged in and not on login/register page, redirect to login
      if (!isLoggedIn && !isLoggingIn && !isSplash) {
        print('  → Redirect to /login (not logged in)');
        return '/login';
      }

      // If logged in and on splash/login page, redirect based on role
      if (isLoggedIn && (isLoggingIn || isSplash)) {
        if (user.isAdmin) {
          print('  → Redirect to /admin/dashboard (ADMIN)');
          return '/admin/dashboard';
        } else {
          print('  → Redirect to /customer/dashboard (USER)');
          return '/customer/dashboard';
        }
      }

      // If logged in and trying to access wrong role routes
      if (isLoggedIn) {
        final isAdminRoute = state.matchedLocation.startsWith('/admin');
        final isCustomerRoute = state.matchedLocation.startsWith('/customer');

        if (user.isAdmin && isCustomerRoute) {
          print('  → Redirect to /admin/dashboard (admin accessing customer route)');
          return '/admin/dashboard';
        }

        if (user.isUser && isAdminRoute) {
          print('  → Redirect to /customer/dashboard (user accessing admin route)');
          return '/customer/dashboard';
        }
      }

      print('  → No redirect');
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Customer Routes
      // Customer Routes wrapped in ShellRoute to persist BottomNavigationBar
      ShellRoute(
        builder: (context, state, child) {
          return CustomerScaffold(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/customer/dashboard',
            builder: (context, state) => const CustomerDashboardPage(),
          ),
          GoRoute(
            path: '/customer/profile',
            builder: (context, state) => const CustomerProfilePage(),
          ),
          GoRoute(
            path: '/customer/invoices',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              final invoiceId = state.uri.queryParameters['invoiceId'];
              final initialTabIndex = tab != null ? int.tryParse(tab) ?? 0 : 0;
              return CustomerInvoicesPage(
                initialTabIndex: initialTabIndex,
                highlightInvoiceId: invoiceId,
              );
            },
          ),
          GoRoute(
            path: '/customer/payment-info',
            builder: (context, state) => const PaymentInfoPage(),
          ),
          GoRoute(
            path: '/customer/help',
            builder: (context, state) => const HelpPage(),
          ),
          GoRoute(
            path: '/customer/wifi',
            builder: (context, state) => const WifiSettingsPage(),
          ),
        ],
      ),

      // Other routes that don't show the bottom nav
      GoRoute(
        path: '/customer/help/faq-wifi-modem',
        builder: (context, state) => const FaqWifiModemPage(),
      ),
      GoRoute(
        path: '/customer/help/tutorial-ganti-wifi',
        builder: (context, state) => const TutorialGantiWifiPage(),
      ),

      // Admin Routes with bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return AdminScaffold(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/customers',
            builder: (context, state) {
              final status = state.uri.queryParameters['status'];
              return AdminCustomersPage(initialStatusFilter: status);
            },
          ),
          GoRoute(
            path: '/admin/invoices',
            builder: (context, state) {
              final status = state.uri.queryParameters['status'];
              final bulan = state.uri.queryParameters['bulan'];
              final tahun = state.uri.queryParameters['tahun'];
              return AdminInvoicesPage(
                initialStatusFilter: status,
                initialMonth: bulan != null ? int.tryParse(bulan) : null,
                initialYear: tahun != null ? int.tryParse(tahun) : null,
              );
            },
          ),
          GoRoute(
            path: '/admin/expenses',
            builder: (context, state) => const AdminExpensesPage(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => const AdminProfilePage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsPage(),
          ),
          GoRoute(
            path: '/admin/payment-methods',
            builder: (context, state) => const AdminPaymentMethodsPage(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const AdminReportsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
