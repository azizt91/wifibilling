import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_method_model.dart';

class PaymentMethodRepository {
  final SupabaseClient _supabase;

  PaymentMethodRepository(this._supabase);

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final response = await _supabase
        .from('payment_methods')
        .select()
        .order('sort_order', ascending: true);

    final data = response as List;
    return data.map((json) => PaymentMethodModel.fromJson(json)).toList();
  }

  Future<List<PaymentMethodModel>> getActivePaymentMethods() async {
    final response = await _supabase
        .from('payment_methods')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final data = response as List;
    return data.map((json) => PaymentMethodModel.fromJson(json)).toList();
  }

  Future<PaymentMethodModel> createPaymentMethod(
      PaymentMethodModel method) async {
    final response = await _supabase
        .from('payment_methods')
        .insert(method.toJson())
        .select()
        .single();

    return PaymentMethodModel.fromJson(response);
  }

  Future<PaymentMethodModel> updatePaymentMethod(
      PaymentMethodModel method) async {
    final response = await _supabase
        .from('payment_methods')
        .update(method.toJson())
        .eq('id', method.id!)
        .select()
        .single();

    return PaymentMethodModel.fromJson(response);
  }

  Future<void> deletePaymentMethod(String id) async {
    await _supabase.from('payment_methods').delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _supabase
        .from('payment_methods')
        .update({'is_active': isActive}).eq('id', id);
  }
}
