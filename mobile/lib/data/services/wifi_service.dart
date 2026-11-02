import 'package:supabase_flutter/supabase_flutter.dart';

class WifiService {
  final SupabaseClient _supabase;

  WifiService(this._supabase);

  /// Get current WiFi info from GenieACS
  Future<Map<String, dynamic>> getCurrentWifiInfo(String ipAddress) async {
    try {
      // Check if GenieACS is enabled
      final genieacsSettings = await _supabase
          .from('genieacs_settings')
          .select('setting_value')
          .eq('setting_key', 'genieacs_enabled')
          .maybeSingle();

      if (genieacsSettings == null || genieacsSettings['setting_value'] != 'true') {
        return {
          'success': false,
          'message': 'GenieACS belum diaktifkan. Hubungi admin untuk mengaktifkan fitur ini.',
        };
      }

      final response = await _supabase.functions.invoke(
        'genieacs-proxy',
        body: {
          'action': 'getCurrentWifi',
          'ipAddress': ipAddress,
        },
      );

      if (response.data != null) {
        return {
          'success': true,
          'ssid': response.data['ssid'] ?? 'Tidak dapat diambil',
          'password': response.data['password'] ?? 'Tidak dapat diambil',
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengambil data WiFi',
      };
    } on FunctionException catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.details ?? e.reasonPhrase ?? "Terjadi kesalahan pada server"}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  /// Change WiFi SSID and/or password via GenieACS
  Future<Map<String, dynamic>> changeWifi({
    required String ipAddress,
    String? newSsid,
    String? newPassword,
  }) async {
    try {
      // Validate input
      if (newSsid == null && newPassword == null) {
        return {
          'success': false,
          'message': 'Minimal isi SSID atau Password baru',
        };
      }

      if (newPassword != null && newPassword.length < 8) {
        return {
          'success': false,
          'message': 'Password minimal 8 karakter',
        };
      }

      // Call Supabase Edge Function
      final response = await _supabase.functions.invoke(
        'genieacs-proxy',
        body: {
          'action': 'changeWifi',
          'ipAddress': ipAddress,
          if (newSsid != null) 'newSsid': newSsid,
          if (newPassword != null) 'newPassword': newPassword,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'WiFi berhasil diganti',
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Gagal mengganti WiFi',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Save WiFi change log to database
  Future<void> saveWifiChangeLog({
    required String customerId,
    required String ipAddress,
    required String oldSsid,
    required String newSsid,
    required String status,
    String? errorMessage,
  }) async {
    try {
      await _supabase.from('wifi_change_logs').insert({
        'customer_id': customerId,
        'ip_address': ipAddress,
        'old_ssid': oldSsid,
        'new_ssid': newSsid,
        'status': status,
        if (errorMessage != null) 'error_message': errorMessage,
      });
    } catch (e) {
      // Log error but don't throw
      print('Error saving WiFi change log: $e');
    }
  }

  /// Get WiFi change history for a customer
  Future<List<Map<String, dynamic>>> getWifiChangeHistory(String customerId) async {
    try {
      final response = await _supabase
          .from('wifi_change_logs')
          .select()
          .eq('customer_id', customerId)
          .order('changed_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting WiFi change history: $e');
      return [];
    }
  }
}
