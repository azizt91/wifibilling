import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    
    authState.when(
      data: (user) {
        if (user != null) {
          print('🔵 [Splash] User logged in: ${user.fullName}');
          print('🔵 [Splash] Role: ${user.role}');
          print('🔵 [Splash] isAdmin: ${user.isAdmin}');
          
          // Redirect based on role
          if (user.isAdmin) {
            print('🔵 [Splash] → Redirecting to /admin/dashboard');
            context.go('/admin/dashboard');
          } else {
            print('🔵 [Splash] → Redirecting to /customer/dashboard');
            context.go('/customer/dashboard');
          }
        } else {
          print('🔵 [Splash] No user, redirecting to /login');
          context.go('/login');
        }
      },
      loading: () {
        print('🔵 [Splash] Auth state loading...');
        // Wait for auth state to load
      },
      error: (error, stack) {
        print('❌ [Splash] Auth error: $error');
        context.go('/login');
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(20), // Padding to make logo smaller inside circle
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle, // Circular shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/wifi_vector.png',
                      fit: BoxFit.contain, // Contain to respect padding
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.wifi,
                          size: 60,
                          color: Color(0xFF667EEA),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Name
                  const Text(
                    'WiFi Billing System',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tagline
                  const Text(
                    'Sistem Billing & Layanan WiFi',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Loading Indicator
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
