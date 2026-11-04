import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'hive_service.dart';

class AppAnalyticsService {
  static const String _keyDeviceId = 'app_analytics_device_id';
  static const String _keyIsInstallRecorded = 'app_analytics_install_recorded';

  /// Merekam instalasi / first open ke Supabase
  static Future<void> trackAppLaunch({String? tenantSlug}) async {
    try {
      final box = Hive.box(HiveService.cacheMetaBox);

      // Ambil atau buat Device ID unik permanen untuk perangkat ini
      String? deviceId = box.get(_keyDeviceId);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await box.put(_keyDeviceId, deviceId);
      }

      final bool isAlreadyRecorded = box.get(_keyIsInstallRecorded, defaultValue: false);
      if (isAlreadyRecorded) {
        return; // Sudah tercatat, tidak perlu mencatat ganda
      }

      // Deteksi model dan OS
      String deviceModel = 'Android Device';
      String osVersion = 'Android';
      try {
        deviceModel = '${Platform.operatingSystem} ${Platform.localHostname}';
        osVersion = Platform.operatingSystemVersion;
      } catch (_) {}

      // Panggil RPC Supabase
      final supabase = Supabase.instance.client;
      await supabase.rpc('record_app_installation', params: {
        'p_device_id': deviceId,
        'p_device_model': deviceModel,
        'p_os_version': osVersion,
        'p_app_version': 'v2.1.0',
        'p_tenant_slug': tenantSlug,
      });

      // Tandai sudah tercatat
      await box.put(_keyIsInstallRecorded, true);
      print('✅ [ANALYTICS] App install recorded successfully: $deviceId');
    } catch (e) {
      print('⚠️ [ANALYTICS] Failed to record app install: $e');
    }
  }
}
