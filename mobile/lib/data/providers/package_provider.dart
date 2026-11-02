import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/package_repository.dart';
import '../models/package_model.dart';
import 'supabase_provider.dart';

// Repository Provider
final packageRepositoryProvider = Provider<PackageRepository>((ref) {
  return PackageRepository(ref.read(supabaseClientProvider));
});

// Packages Provider
final packagesProvider = FutureProvider.autoDispose<List<PackageModel>>((ref) async {
  final repository = ref.watch(packageRepositoryProvider);
  return repository.getPackages();
});

// Package Controller
class PackageController extends StateNotifier<AsyncValue<void>> {
  final PackageRepository _repository;

  PackageController(this._repository) : super(const AsyncValue.data(null));

  Future<PackageModel> createPackage({
    required String packageName,
    required double price,
    required int speedMbps,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final package = await _repository.createPackage(
        packageName: packageName,
        price: price,
        speedMbps: speedMbps,
        description: description,
      );
      state = const AsyncValue.data(null);
      return package;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<PackageModel> updatePackage({
    required int id,
    required String packageName,
    required double price,
    required int speedMbps,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final package = await _repository.updatePackage(
        id: id,
        packageName: packageName,
        price: price,
        speedMbps: speedMbps,
        description: description,
      );
      state = const AsyncValue.data(null);
      return package;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deletePackage(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deletePackage(id);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final packageControllerProvider =
    StateNotifierProvider<PackageController, AsyncValue<void>>((ref) {
  return PackageController(ref.read(packageRepositoryProvider));
});
