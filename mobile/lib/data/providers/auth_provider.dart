import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../repositories/auth_repository.dart';

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(supabaseClientProvider));
});

// Auth State Provider - Watches current user session
final authStateProvider = StreamProvider<ProfileModel?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges();
});

// Current User Provider
final currentUserProvider = FutureProvider<ProfileModel?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getCurrentUser();
});

// Auth Controller Provider
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref _ref;

  AuthController(this._ref);

  AuthRepository get _authRepo => _ref.read(authRepositoryProvider);

  // Login
  Future<ProfileModel> login({
    required String email,
    required String password,
  }) async {
    return await _authRepo.login(email: email, password: password);
  }

  // Register
  Future<ProfileModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _authRepo.register(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  // Logout
  Future<void> logout() async {
    await _authRepo.logout();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authRepo.isLoggedIn();
  }

  // Get current user
  Future<ProfileModel?> getCurrentUser() async {
    return await _authRepo.getCurrentUser();
  }

  // Update profile
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    return await _authRepo.updateProfile(profile);
  }

  // Change password
  Future<void> changePassword(String newPassword) async {
    await _authRepo.changePassword(newPassword);
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _authRepo.resetPassword(email);
  }
}
