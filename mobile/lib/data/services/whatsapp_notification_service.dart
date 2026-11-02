import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/profile_model.dart';
import '../models/invoice_model.dart';

/// Service untuk mengirim notifikasi WhatsApp melalui Supabase Edge Function
class WhatsAppNotificationService {
  final SupabaseClient _supabase;

  WhatsAppNotificationService(this._supabase);

  /// Invoke Supabase Function untuk mengirim WhatsApp notification
  Future<Map<String, dynamic>> _invokeWhatsappFunction(
    String target,
    String message,
  ) async {
    try {
      print('Memanggil Supabase Function send-whatsapp-notification untuk target: $target');

      final response = await _supabase.functions.invoke(
        'send-whatsapp-notification',
        body: {
          'target': target,
          'message': message,
        },
      );

      if (response.data == null) {
        return {
          'success': false,
          'message': 'No response from function',
        };
      }

      print('Respons dari Supabase function: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == false) {
        print('Error dari dalam function: ${data['message']}');
        return {
          'success': false,
          'message': 'API Error: ${data['message']}',
        };
      }

      return {
        'success': true,
        'message': 'Notifikasi WhatsApp berhasil diproses',
        'response': data,
      };
    } catch (e) {
      print('Supabase function invocation failed: $e');
      return {
        'success': false,
        'message': 'Error memanggil fungsi: $e',
      };
    }
  }

  /// Kirim notifikasi pembayaran ke pelanggan
  Future<Map<String, dynamic>> sendCustomerPaymentNotification({
    required ProfileModel customerData,
    required InvoiceModel invoiceData,
    required String paymentMethod,
  }) async {
    // Check if WhatsApp number exists
    if (customerData.phone == null || customerData.phone!.isEmpty) {
      print('Nomor WhatsApp pelanggan tidak tersedia.');
      return {
        'success': false,
        'message': 'Nomor WhatsApp pelanggan tidak ada.',
      };
    }

    try {
      // Check if auto notification is enabled
      final autoNotifResponse = await _supabase
          .from('whatsapp_settings')
          .select('setting_value')
          .eq('setting_key', 'auto_notification_enabled')
          .maybeSingle();

      if (autoNotifResponse?['setting_value'] != 'true') {
        print('Auto notification is disabled');
        return {
          'success': true,
          'message': 'Notifikasi otomatis dinonaktifkan',
        };
      }

      // Check if Fonnte token is configured
      final tokenResponse = await _supabase
          .from('whatsapp_settings')
          .select('setting_value')
          .eq('setting_key', 'fonnte_token')
          .maybeSingle();

      if (tokenResponse != null && tokenResponse['setting_value'] == '') {
        print('Fonnte token not configured in database. Make sure it is set in Supabase Secrets.');
      }

      // Get WhatsApp settings
      final whatsappSettingsResponse = await _supabase
          .from('whatsapp_settings')
          .select('*');

      final settings = <String, String>{};
      for (final setting in whatsappSettingsResponse) {
        settings[setting['setting_key']] = setting['setting_value'] ?? '';
      }

      // Get customer email
      String customerEmail = 'email_login_anda';
      try {
        final emailResponse = await _supabase.rpc(
          'get_user_email',
          params: {'user_id': customerData.id},
        );
        if (emailResponse != null) {
          customerEmail = emailResponse.toString();
        }
      } catch (err) {
        print('Gagal mengambil email pelanggan untuk notifikasi: $err');
      }

      // Format phone number
      String target = customerData.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (target.startsWith('0')) {
        target = '62${target.substring(1)}';
      }

      // Payment method text
      final paymentMethodText = {
        'cash': 'Tunai',
        'transfer': 'Transfer Bank',
        'ewallet': 'E-Wallet',
        'qris': 'QRIS',
      }[paymentMethod] ?? 'Tunai';

      // Get template based on payment type
      final template = invoiceData.status == 'paid'
          ? settings['template_payment_full'] ?? ''
          : settings['template_payment_installment'] ?? '';

      // Format currency
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      // Replace variables in template
      final message = template
          .replaceAll('{nama_pelanggan}', customerData.fullName ?? '')
          .replaceAll('{idpl}', customerData.idpl ?? '')
          .replaceAll('{periode}', invoiceData.invoicePeriod)
          .replaceAll('{total_tagihan}', formatter.format(invoiceData.amount))
          .replaceAll('{jumlah_dibayar}', formatter.format(invoiceData.amount))
          .replaceAll(
            '{sisa_tagihan}',
            formatter.format(invoiceData.remainingAmount ?? 0),
          )
          .replaceAll('{metode_pembayaran}', paymentMethodText)
          .replaceAll(
            '{app_url}',
            settings['app_url'] ?? 'http://selinggonet.netlify.app/',
          )
          .replaceAll('{email_pelanggan}', customerEmail);

      return await _invokeWhatsappFunction(target, message);
    } catch (e) {
      print('Error sending WhatsApp notification: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Send custom WhatsApp message
  Future<Map<String, dynamic>> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Format phone number
      String target = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (target.startsWith('0')) {
        target = '62${target.substring(1)}';
      }

      return await _invokeWhatsappFunction(target, message);
    } catch (e) {
      print('Error sending WhatsApp message: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Get current admin name
  Future<String> getCurrentAdminName() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'Admin';

      final profileResponse = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      return profileResponse?['full_name'] ?? 'Admin';
    } catch (error) {
      print('Error getting admin name: $error');
      return 'Admin';
    }
  }
}
