import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_method_model.dart';
import '../repositories/payment_repository.dart';
import 'auth_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.read(supabaseClientProvider));
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getActivePaymentMethods();
});
