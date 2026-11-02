import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/whatsapp_notification_service.dart';
import '../models/profile_model.dart';
import '../models/invoice_model.dart';

/// Provider untuk WhatsApp Notification Service
final whatsappNotificationServiceProvider = Provider<WhatsAppNotificationService>((ref) {
  return WhatsAppNotificationService(Supabase.instance.client);
});

/// Controller untuk mengirim WhatsApp notifications
class WhatsAppNotificationController extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final WhatsAppNotificationService _service;

  WhatsAppNotificationController(this._service) : super(const AsyncValue.data({}));

  /// Kirim notifikasi pembayaran ke pelanggan
  Future<Map<String, dynamic>> sendPaymentNotification({
    required ProfileModel customerData,
    required InvoiceModel invoiceData,
    required String paymentMethod,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.sendCustomerPaymentNotification(
        customerData: customerData,
        invoiceData: invoiceData,
        paymentMethod: paymentMethod,
      );

      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Get current admin name
  Future<String> getAdminName() async {
    return await _service.getCurrentAdminName();
  }
}

/// Provider untuk WhatsApp Notification Controller
final whatsappNotificationControllerProvider =
    StateNotifierProvider<WhatsAppNotificationController, AsyncValue<Map<String, dynamic>>>((ref) {
  final service = ref.watch(whatsappNotificationServiceProvider);
  return WhatsAppNotificationController(service);
});
