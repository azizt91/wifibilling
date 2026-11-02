import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Stream of auth state changes
  Stream<ProfileModel?> authStateChanges() {
    return _supabase.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;

      try {
        final response = await _supabase
            .from('profiles')
            .select('*, packages(*)')
            .eq('id', user.id)
            .single();

        return ProfileModel.fromJson(response);
      } catch (e) {
        print('Error fetching profile: $e');
        return null;
      }
    });
  }

  // Login with email and password
  Future<ProfileModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login gagal. Silakan coba lagi.');
      }

      // Fetch profile
      final profileResponse = await _supabase
          .from('profiles')
          .select('*, packages(*)')
          .eq('id', response.user!.id)
          .single();

      // Add email from auth.users
      final profileData = Map<String, dynamic>.from(profileResponse);
      profileData['email'] = response.user!.email;

      return ProfileModel.fromJson(profileData);
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Register new user
  Future<ProfileModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Registrasi gagal. Silakan coba lagi.');
      }

      // Create profile
      final profileData = {
        'id': response.user!.id,
        'full_name': fullName,
        'role': 'ADMIN', // Default role for registration
        'email': response.user!.email,
      };

      await _supabase.from('profiles').insert(profileData);

      // Fetch created profile
      final profileResponse = await _supabase
          .from('profiles')
          .select('*, packages(*)')
          .eq('id', response.user!.id)
          .single();

      return ProfileModel.fromJson(profileResponse);
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Gagal logout: ${e.toString()}');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final session = _supabase.auth.currentSession;
    return session != null;
  }

  // Get current user
  Future<ProfileModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('*, packages(*)')
          .eq('id', user.id)
          .single();

      // Add email from auth.users
      final profileData = Map<String, dynamic>.from(response);
      profileData['email'] = user.email;

      return ProfileModel.fromJson(profileData);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Update profile
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      await _supabase
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', profile.id)
          .single();

      return ProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal update profile: ${e.toString()}');
    }
  }

  // Change password
  Future<void> changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Gagal mengubah password: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Gagal reset password: ${e.toString()}');
    }
  }

  // Helper method to get user-friendly error messages
  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email atau password salah';
    } else if (message.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi. Silakan cek email Anda.';
    } else if (message.contains('User already registered')) {
      return 'Email sudah terdaftar';
    } else if (message.contains('Password should be at least')) {
      return 'Password minimal 6 karakter';
    } else if (message.contains('Unable to validate email address')) {
      return 'Format email tidak valid';
    }
    return message;
  }
}
