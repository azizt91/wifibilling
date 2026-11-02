import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/genieacs_settings_model.dart';

class GenieAcsRepository {
  final SupabaseClient _supabase;

  GenieAcsRepository(this._supabase);

  /// Get all GenieACS settings
  Future<List<GenieAcsSettingsModel>> getSettings() async {
    try {
      final response = await _supabase
          .from('genieacs_settings')
          .select()
          .order('setting_key');

      return (response as List)
          .map((e) => GenieAcsSettingsModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch GenieACS settings: $e');
    }
  }

  /// Get GenieACS config as a single object
  Future<GenieAcsConfig> getConfig() async {
    final settings = await getSettings();
    return GenieAcsConfig.fromSettings(settings);
  }

  /// Save GenieACS settings
  Future<void> saveSettings(GenieAcsConfig config) async {
    try {
      final settingsMap = config.toSettingsMap();

      for (final entry in settingsMap.entries) {
        // Try to update first
        final updateResponse = await _supabase
            .from('genieacs_settings')
            .update({
              'setting_value': entry.value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('setting_key', entry.key)
            .select();

        // If no rows updated, insert new
        if (updateResponse.isEmpty) {
          await _supabase.from('genieacs_settings').insert({
            'setting_key': entry.key,
            'setting_value': entry.value,
            'is_enabled': true,
          });
        }
      }
    } catch (e) {
      throw Exception('Failed to save GenieACS settings: $e');
    }
  }

  /// Update a single setting
  Future<void> updateSetting(String key, String value) async {
    try {
      final updateResponse = await _supabase
          .from('genieacs_settings')
          .update({
            'setting_value': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('setting_key', key)
          .select();

      if (updateResponse.isEmpty) {
        await _supabase.from('genieacs_settings').insert({
          'setting_key': key,
          'setting_value': value,
          'is_enabled': true,
        });
      }
    } catch (e) {
      throw Exception('Failed to update GenieACS setting: $e');
    }
  }

  /// Toggle GenieACS enabled status
  Future<void> toggleEnabled(bool enabled) async {
    await updateSetting('genieacs_enabled', enabled.toString());
  }

  /// Check if GenieACS is enabled
  Future<bool> isEnabled() async {
    try {
      final response = await _supabase
          .from('genieacs_settings')
          .select('setting_value')
          .eq('setting_key', 'genieacs_enabled')
          .maybeSingle();

      if (response == null) return false;
      return response['setting_value'] == 'true';
    } catch (e) {
      return false;
    }
  }
}
