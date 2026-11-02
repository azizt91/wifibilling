import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/genieacs_repository.dart';
import '../models/genieacs_settings_model.dart';
import 'supabase_provider.dart';

// Repository Provider
final genieacsRepositoryProvider = Provider<GenieAcsRepository>((ref) {
  return GenieAcsRepository(ref.read(supabaseClientProvider));
});

// Settings Provider
final genieacsSettingsProvider = FutureProvider<List<GenieAcsSettingsModel>>((ref) async {
  final repository = ref.watch(genieacsRepositoryProvider);
  return repository.getSettings();
});

// Config Provider
final genieacsConfigProvider = FutureProvider<GenieAcsConfig>((ref) async {
  final repository = ref.watch(genieacsRepositoryProvider);
  return repository.getConfig();
});

// Enabled Status Provider
final genieacsEnabledProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(genieacsRepositoryProvider);
  return repository.isEnabled();
});

// Controller
class GenieAcsController extends StateNotifier<AsyncValue<void>> {
  final GenieAcsRepository _repository;

  GenieAcsController(this._repository) : super(const AsyncValue.data(null));

  Future<void> saveSettings(GenieAcsConfig config) async {
    state = const AsyncValue.loading();
    try {
      await _repository.saveSettings(config);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateSetting(String key, String value) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateSetting(key, value);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> toggleEnabled(bool enabled) async {
    state = const AsyncValue.loading();
    try {
      await _repository.toggleEnabled(enabled);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final genieacsControllerProvider =
    StateNotifierProvider<GenieAcsController, AsyncValue<void>>((ref) {
  return GenieAcsController(ref.read(genieacsRepositoryProvider));
});
