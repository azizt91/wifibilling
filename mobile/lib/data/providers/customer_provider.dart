import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/customer_repository.dart';
import '../models/profile_model.dart';
import 'supabase_provider.dart';
import 'cache_provider.dart';

// Customer Repository Provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    ref.read(supabaseClientProvider),
    ref.read(cacheServiceProvider),
    ref.read(connectivityServiceProvider),
  );
});

// Filter State Providers
final customerSearchQueryProvider = StateProvider<String>((ref) => '');
final customerStatusFilterProvider = StateProvider<String>((ref) => 'all');
final customerPackageFilterProvider = StateProvider<String>((ref) => 'all');
final customerPageProvider = StateProvider<int>((ref) => 1);

// Customers List Provider
final customersProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  final searchQuery = ref.watch(customerSearchQueryProvider);
  final statusFilter = ref.watch(customerStatusFilterProvider);
  final packageFilter = ref.watch(customerPackageFilterProvider);
  final page = ref.watch(customerPageProvider);

  return repository.getCustomers(
    page: page,
    limit: 20,
    searchQuery: searchQuery.isEmpty ? null : searchQuery,
    statusFilter: statusFilter == 'all' ? null : statusFilter,
    packageFilter: packageFilter == 'all' ? null : packageFilter,
  );
});

// Customer Count Provider (for pagination)
final customerCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  final searchQuery = ref.watch(customerSearchQueryProvider);
  final statusFilter = ref.watch(customerStatusFilterProvider);
  final packageFilter = ref.watch(customerPackageFilterProvider);

  return repository.getCustomerCount(
    searchQuery: searchQuery.isEmpty ? null : searchQuery,
    statusFilter: statusFilter == 'all' ? null : statusFilter,
    packageFilter: packageFilter == 'all' ? null : packageFilter,
  );
});

// Single Customer Provider
final customerByIdProvider = FutureProvider.autoDispose.family<ProfileModel, String>(
  (ref, id) async {
    final repository = ref.watch(customerRepositoryProvider);
    return repository.getCustomerById(id);
  },
);

// Customer Stats Provider
final customerStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.getCustomerStats();
});

// Customer Controller (for CRUD operations)
class CustomerController extends StateNotifier<AsyncValue<void>> {
  final CustomerRepository _repository;

  CustomerController(this._repository) : super(const AsyncValue.data(null));

  Future<ProfileModel> createCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
    required String packageId,
    String? latitude,
    String? longitude,
    String? ipStaticPppoe,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final customer = await _repository.createCustomer(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        address: address,
        packageId: packageId,
        latitude: latitude,
        longitude: longitude,
        ipStaticPppoe: ipStaticPppoe,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return customer;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<ProfileModel> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? address,
    String? packageId,
    String? status,
    String? latitude,
    String? longitude,
    String? ipStaticPppoe,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final customer = await _repository.updateCustomer(
        id: id,
        fullName: fullName,
        phone: phone,
        address: address,
        packageId: packageId,
        status: status,
        latitude: latitude,
        longitude: longitude,
        ipStaticPppoe: ipStaticPppoe,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return customer;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteCustomer(id);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<ProfileModel> toggleStatus(String id, String currentStatus) async {
    state = const AsyncValue.loading();
    try {
      final customer = await _repository.toggleCustomerStatus(id, currentStatus);
      state = const AsyncValue.data(null);
      return customer;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final customerControllerProvider =
    StateNotifierProvider<CustomerController, AsyncValue<void>>((ref) {
  return CustomerController(ref.read(customerRepositoryProvider));
});
