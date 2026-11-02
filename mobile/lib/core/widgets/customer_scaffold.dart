import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class CustomerScaffold extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const CustomerScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<CustomerScaffold> createState() => _CustomerScaffoldState();
}

class _CustomerScaffoldState extends State<CustomerScaffold> {
  static final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _getSelectedIndex() {
    if (widget.currentRoute.contains('/customer/dashboard')) return 0;
    if (widget.currentRoute.contains('/customer/invoices')) return 1;
    if (widget.currentRoute.contains('/customer/help')) return 2;
    if (widget.currentRoute.contains('/customer/profile') ||
        widget.currentRoute.contains('/customer/wifi') ||
        widget.currentRoute.contains('/customer/payment-info')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
      key: _scaffoldKey,
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/customer/dashboard');
              break;
            case 1:
              context.go('/customer/invoices');
              break;
            case 2:
              context.go('/customer/help');
              break;
            case 3:
              context.go('/customer/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Bantuan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }
}
