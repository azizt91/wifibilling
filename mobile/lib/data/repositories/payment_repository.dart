import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_method_model.dart';

class PaymentRepository {
  final SupabaseClient _supabase;

  PaymentRepository(this._supabase);

  Future<List<PaymentMethodModel>> getActivePaymentMethods() async {
    try {
      final response = await _supabase
          .from('payment_methods')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((e) => PaymentMethodModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch payment methods: $e');
    }
  }
}
