import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/app_settings_model.dart';

class AppSettingsRepository {
  final SupabaseClient _supabase;

  AppSettingsRepository(this._supabase);

  Future<AppSettingsModel?> getAppSettings() async {
    final response = await _supabase
        .from('app_settings')
        .select()
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return AppSettingsModel.fromJson(response);
  }

  Future<AppSettingsModel> saveAppSettings(AppSettingsModel settings) async {
    // Get existing settings to get ID
    final existing = await getAppSettings();
    
    final data = settings.toJson();
    if (existing?.id != null) {
      data['id'] = existing!.id;
    }

    final response = await _supabase
        .from('app_settings')
        .upsert(data)
        .select()
        .single();

    return AppSettingsModel.fromJson(response);
  }

  Future<String?> uploadQrisImage(List<int> bytes, String fileName) async {
    final filePath = 'qris/$fileName';
    
    await _supabase.storage
        .from('app-assets')
        .uploadBinary(filePath, Uint8List.fromList(bytes));

    return _supabase.storage.from('app-assets').getPublicUrl(filePath);
  }

  // WhatsApp Settings
  Future<Map<String, String>> getWhatsAppSettings() async {
    final response = await _supabase
        .from('whatsapp_settings')
        .select();

    final data = response as List;
    final settings = <String, String>{};
    
    for (var item in data) {
      final model = WhatsAppSettingsModel.fromJson(item);
      settings[model.settingKey] = model.settingValue;
    }
    
    return settings;
  }

  Future<void> saveWhatsAppSetting(String key, String value) async {
    await _supabase
        .from('whatsapp_settings')
        .upsert({
          'setting_key': key,
          'setting_value': value,
        });
  }

  Future<void> saveWhatsAppSettings(Map<String, String> settings) async {
    final List<Map<String, dynamic>> data = [];
    
    settings.forEach((key, value) {
      data.add({
        'setting_key': key,
        'setting_value': value,
      });
    });

    await _supabase.from('whatsapp_settings').upsert(data);
  }
}
