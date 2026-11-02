import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_service.dart';
import 'supabase_provider.dart';

// WiFi Service Provider
final wifiServiceProvider = Provider<WifiService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return WifiService(supabase);
});

// Current WiFi Info Provider
final currentWifiInfoProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, ipAddress) async {
  final wifiService = ref.watch(wifiServiceProvider);
  return await wifiService.getCurrentWifiInfo(ipAddress);
});

// WiFi Change History Provider
final wifiChangeHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  final wifiService = ref.watch(wifiServiceProvider);
  return await wifiService.getWifiChangeHistory(customerId);
});

// WiFi Controller
class WifiController extends StateNotifier<AsyncValue<void>> {
  final WifiService _wifiService;

  WifiController(this._wifiService) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>> changeWifi({
    required String customerId,
    required String ipAddress,
    required String oldSsid,
    String? newSsid,
    String? newPassword,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Call WiFi service to change WiFi
      final result = await _wifiService.changeWifi(
        ipAddress: ipAddress,
        newSsid: newSsid,
        newPassword: newPassword,
      );

      // Save log
      await _wifiService.saveWifiChangeLog(
        customerId: customerId,
        ipAddress: ipAddress,
        oldSsid: oldSsid,
        newSsid: newSsid ?? oldSsid,
        status: result['success'] == true ? 'success' : 'failed',
        errorMessage: result['success'] == true ? null : result['message'],
      );

      state = const AsyncValue.data(null);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}

final wifiControllerProvider = StateNotifierProvider<WifiController, AsyncValue<void>>((ref) {
  final wifiService = ref.watch(wifiServiceProvider);
  return WifiController(wifiService);
});
