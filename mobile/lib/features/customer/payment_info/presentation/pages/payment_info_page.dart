import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/providers/app_settings_provider.dart';
import '../../../../../data/providers/payment_method_provider.dart';
import '../../../../../data/providers/auth_provider.dart';

class PaymentInfoPage extends ConsumerWidget {
  const PaymentInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final paymentMethodsAsync = ref.watch(activePaymentMethodsProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Pembayaran'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appSettingsProvider);
          ref.invalidate(activePaymentMethodsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Info
              settingsAsync.when(
                data: (settings) {
                  if (settings == null) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kontak Kami',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (settings.whatsappNumber != null)
                        _buildInfoCard(
                          icon: Icons.phone,
                          title: 'WhatsApp',
                          value: settings.whatsappNumber!,
                          color: Colors.green,
                        ),
                      if (settings.supportEmail != null)
                        _buildInfoCard(
                          icon: Icons.email,
                          title: 'Email',
                          value: settings.supportEmail!,
                          color: Colors.blue,
                        ),
                      if (settings.officeAddress != null)
                        _buildInfoCard(
                          icon: Icons.location_on,
                          title: 'Alamat',
                          value: settings.officeAddress!,
                          color: Colors.red,
                        ),
                      const SizedBox(height: 24),
                      
                      // Offline Payment Info
                      if (settings.offlinePaymentName != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pembayaran Offline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      settings.offlinePaymentName!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (settings.offlinePaymentAddress != null)
                                      Text(
                                        settings.offlinePaymentAddress!,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _requestLocationViaWhatsApp(ref, settings.whatsappNumber),
                                      icon: const Icon(Icons.location_on),
                                      label: const Text('Minta Alamat Lengkap'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      
                      // QRIS
                      if (settings.showQris && settings.qrisImageUrl != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QRIS Payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Scan QR Code untuk pembayaran',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () => _showQrisModal(context, settings.qrisImageUrl!),
                                      child: Image.network(
                                        settings.qrisImageUrl!,
                                        height: 250,
                                        errorBuilder: (context, error, stack) =>
                                            const Icon(Icons.qr_code, size: 100),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ketuk untuk memperbesar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
              
              // Bank Transfer
              const Text(
                'Transfer Bank',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              paymentMethodsAsync.when(
                data: (methods) {
                  if (methods.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Belum ada metode pembayaran tersedia'),
                      ),
                    );
                  }
                  
                  return Column(
                    children: methods.map((method) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.account_balance,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            method.bankName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. Rek: ${method.accountNumber}'),
                              Text('a.n. ${method.accountHolder}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () => _copyToClipboard(context, method.accountNumber),
                            tooltip: 'Salin nomor rekening',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading payment methods'),
              ),
              
              const SizedBox(height: 24),
              
              // WhatsApp Confirmation Button
              settingsAsync.when(
                data: (settings) {
                  if (settings?.whatsappNumber == null) return const SizedBox.shrink();
                  
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmTransferViaWhatsApp(ref, settings?.whatsappNumber),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Konfirmasi Transfer via WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
  
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nomor rekening $text berhasil disalin!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showQrisModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('QRIS Payment'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.qr_code, size: 200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _confirmTransferViaWhatsApp(WidgetRef ref, String? whatsappNumber) async {
    if (whatsappNumber == null) return;
    
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH:mm', 'id_ID');
    
    final message = '''
🏦 *KONFIRMASI PEMBAYARAN TRANSFER*

Halo Admin Selinggonet,

Saya ingin mengkonfirmasi pembayaran tagihan internet:

👤 *Nama:* ${user.fullName ?? user.email}
🆔 *ID Pelanggan:* ${user.idpl ?? 'N/A'}
📅 *Tanggal:* ${dateFormat.format(now)}
🕐 *Waktu:* ${timeFormat.format(now)}

💰 *Status:* Sudah melakukan transfer pembayaran
📋 *Keterangan:* Mohon verifikasi pembayaran saya

Bukti transfer akan saya kirim setelah pesan ini.

Terima kasih! 🙏

_Pesan otomatis dari aplikasi Selinggonet_
''';
    
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
  
  Future<void> _requestLocationViaWhatsApp(WidgetRef ref, String? whatsappNumber) async {
    if (whatsappNumber == null) return;
    
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    final message = '''
📍 *PERMINTAAN ALAMAT LENGKAP*

Halo Admin Selinggonet,

Saya ingin mendapatkan alamat lengkap untuk pembayaran langsung:

👤 *Nama:* ${user.fullName ?? user.email}
🆔 *ID Pelanggan:* ${user.idpl ?? 'N/A'}
🏠 *Keperluan:* Pembayaran tagihan langsung ke rumah

Mohon dikirimkan:
• Alamat lengkap
• Koordinat lokasi (jika ada)
• Jam operasional terbaru

Terima kasih! 🙏

_Pesan otomatis dari aplikasi Selinggonet_
''';
    
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(value),
        trailing: value.startsWith('08') || value.startsWith('62')
            ? IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () async {
                  final url = Uri.parse('https://wa.me/$value');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                tooltip: 'Hubungi via WhatsApp',
              )
            : null,
      ),
    );
  }
}
