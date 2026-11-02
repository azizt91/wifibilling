import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings_model.dart';
import '../repositories/app_settings_repository.dart';
import 'auth_provider.dart';

// Repository Provider
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AppSettingsRepository(supabase);
});

// App Settings Provider
final appSettingsProvider = FutureProvider<AppSettingsModel?>((ref) async {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return repository.getAppSettings();
});

// WhatsApp Settings Provider
final whatsappSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return repository.getWhatsAppSettings();
});

// App Settings Controller
class AppSettingsController extends StateNotifier<AsyncValue<void>> {
  final AppSettingsRepository _repository;

  AppSettingsController(this._repository) : super(const AsyncValue.data(null));

  Future<void> saveAppSettings(AppSettingsModel settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.saveAppSettings(settings);
    });
  }

  Future<String?> uploadQrisImage(List<int> bytes, String fileName) async {
    return await _repository.uploadQrisImage(bytes, fileName);
  }

  Future<void> saveWhatsAppSettings(Map<String, String> settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.saveWhatsAppSettings(settings);
    });
  }
}

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AsyncValue<void>>((ref) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return AppSettingsController(repository);
});
