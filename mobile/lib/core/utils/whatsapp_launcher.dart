import 'package:url_launcher/url_launcher.dart';

class WhatsAppLauncher {
  /// Launches WhatsApp with the given phone number and optional message.
  /// 
  /// [phone] The phone number to send the message to. Can be in local format (08...) or international (+62...).
  /// [message] The optional message to pre-fill.
  /// [onError] Callback function to handle errors if WhatsApp cannot be launched.
  static Future<void> launchWhatsApp({
    required String phone,
    String? message,
    required Function(String) onError,
  }) async {
    try {
      // 1. Format phone number
      String formattedPhone = phone.replaceAll(RegExp(r'[^\d+]'), ''); // Remove non-digit chars except +
      
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '62${formattedPhone.substring(1)}';
      } else if (formattedPhone.startsWith('+')) {
        formattedPhone = formattedPhone.substring(1);
      }
      
      // 2. Construct URL
      // Using https://wa.me/ is generally more reliable across platforms (Android/iOS/Web)
      // than whatsapp:// scheme, as it handles fallbacks better.
      final Uri url = Uri.parse(
        'https://wa.me/$formattedPhone${message != null ? "?text=${Uri.encodeComponent(message)}" : ""}',
      );

      // 3. Launch URL
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        onError('Tidak dapat membuka WhatsApp. Pastikan aplikasi terinstall.');
      }
    } catch (e) {
      onError('Terjadi kesalahan: $e');
    }
  }
}
