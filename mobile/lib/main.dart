import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/hive_service.dart';

void main() async {
  // Catch all errors and display them
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ [FLUTTER ERROR] ${details.exception}');
    print('Stack: ${details.stack}');
  };

  print('🚀 [MAIN] Starting WiFi Billing System...');
  
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ [MAIN] Flutter binding initialized');

  String? initError;

  // Initialize Date Formatting (FIX LocaleDataException)
  try {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
    print('✅ [MAIN] Date formatting initialized (id_ID)');
  } catch (e, stack) {
    print('❌ [MAIN] Date formatting init failed: $e');
    print('Stack: $stack');
    // Non-critical, continue
  }

  // Initialize Hive
  try {
    await HiveService.init();
    print('✅ [MAIN] Hive initialized');
  } catch (e, stack) {
    print('❌ [MAIN] Hive init failed: $e');
    print('Stack: $stack');
    initError = 'Hive init failed: $e';
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    print('✅ [MAIN] Supabase initialized');
    print('🔗 [MAIN] Supabase URL: ${AppConstants.supabaseUrl}');
  } catch (e, stack) {
    print('❌ [MAIN] Supabase init failed: $e');
    print('Stack: $stack');
    initError = 'Supabase init failed: $e';
  }

  print('🎯 [MAIN] Running app...');
  runApp(
    ProviderScope(
      child: initError != null 
        ? MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 20),
                      const Text(
                        'Initialization Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        initError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SelinggonetApp(),
    ),
  );
}

class SelinggonetApp extends ConsumerWidget {
  const SelinggonetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      print('🔵 [APP] Building SelinggonetApp...');
      final router = ref.watch(routerProvider);
      print('✅ [APP] Router initialized');

      return MaterialApp.router(
        title: 'WiFi Billing System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: router,
        builder: (context, child) {
          // Error boundary for runtime errors
          ErrorWidget.builder = (FlutterErrorDetails details) {
            print('❌ [ERROR WIDGET] ${details.exception}');
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 20),
                      const Text(
                        'Runtime Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        details.exception.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Try to go back or restart
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          };
          return child ?? const SizedBox();
        },
      );
    } catch (e, stack) {
      print('❌ [APP] Build error: $e');
      print('Stack: $stack');
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'App Build Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
