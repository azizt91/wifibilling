import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_method_model.dart';
import '../repositories/payment_method_repository.dart';
import 'auth_provider.dart';

// Repository Provider
final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PaymentMethodRepository(supabase);
});

// Payment Methods List Provider
final paymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>((ref) async {
  final repository = ref.watch(paymentMethodRepositoryProvider);
  return repository.getPaymentMethods();
});

// Active Payment Methods Provider (for customer use)
final activePaymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>((ref) async {
  final repository = ref.watch(paymentMethodRepositoryProvider);
  return repository.getActivePaymentMethods();
});

// Payment Method Controller
class PaymentMethodController extends StateNotifier<AsyncValue<void>> {
  final PaymentMethodRepository _repository;

  PaymentMethodController(this._repository) : super(const AsyncValue.data(null));

  Future<void> createPaymentMethod(PaymentMethodModel method) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createPaymentMethod(method);
    });
  }

  Future<void> updatePaymentMethod(PaymentMethodModel method) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updatePaymentMethod(method);
    });
  }

  Future<void> deletePaymentMethod(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deletePaymentMethod(id);
    });
  }

  Future<void> toggleActive(String id, bool isActive) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.toggleActive(id, isActive);
    });
  }
}

final paymentMethodControllerProvider =
    StateNotifierProvider<PaymentMethodController, AsyncValue<void>>((ref) {
  final repository = ref.watch(paymentMethodRepositoryProvider);
  return PaymentMethodController(repository);
});
