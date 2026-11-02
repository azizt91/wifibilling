import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/tenant_subscription_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/tenant_subscription_provider.dart';
import '../constants/app_constants.dart';
import '../utils/whatsapp_launcher.dart';

class SubscriptionLockOverlay extends ConsumerWidget {
  final TenantSubscriptionModel subscription;

  const SubscriptionLockOverlay({
    super.key,
    required this.subscription,
  });

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  void _copyDana(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: AppConstants.ownerDanaNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nomor DANA berhasil disalin!'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchWhatsAppConfirmation(BuildContext context) {
    final priceStr = _formatCurrency(subscription.priceMonthly);
    final waMsg = 'Halo Admin WiFi Billing, akun saya terkunci karena masa tenggang telah lewat:\n\n'
        '• Nama Usaha: ${subscription.name}\n'
        '• Paket Langganan: ${subscription.planName} ($priceStr/bln)\n'
        '• Status: Terkunci (Lewat ${subscription.daysOverdue} hari)\n\n'
        'Berikut bukti transfer terlampir. Mohon akun saya diaktifkan kembali. Terima kasih!';

    WhatsAppLauncher.launchWhatsApp(
      phone: AppConstants.ownerWhatsApp,
      message: waMsg,
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceStr = _formatCurrency(subscription.priceMonthly);
    final isSuspended = subscription.isSuspended;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Merah Terkunci
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFB91C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0x2EFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Akses Sistem Terkunci',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isSuspended
                                      ? 'Akun ditangguhkan oleh Administrator'
                                      : 'Masa tenggang 3 hari berakhir (Hari ke-${subscription.daysOverdue} jatuh tempo)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFFFE4E6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Penjelasan
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Text(
                              'Halo pengelola ${subscription.name}, masa aktif paket langganan usaha Anda telah habis dan melewati batas toleransi masa tenggang (4 hari). Fitur pembuatan tagihan, pembukuan keuangan, dan cetak struk kasir dibekukan sementara hingga perpanjangan diverifikasi.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF881337),
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Detail Tagihan Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow('Nama Usaha', subscription.name),
                                const SizedBox(height: 8),
                                _buildDetailRow('Paket Langganan', subscription.planName, valueColor: const Color(0xFF4F46E5)),
                                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Biaya Perpanjangan:',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    Text(
                                      '$priceStr / bln',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Metode 1: QRIS
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'METODE 1: SCAN QRIS',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(4),
                                    child: Image.asset(
                                      'assets/images/qris_owner.jpg',
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                        height: 80,
                                        child: Center(
                                          child: Text('QRIS Pembayaran'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Bisa di-scan dengan BCA, DANA, GoPay, OVO, ShopeePay, atau m-Banking.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Metode 2: Transfer DANA
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'METODE 2: TRANSFER DANA',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        AppConstants.ownerDanaNumber,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'a.n. ${AppConstants.ownerDanaName}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _copyDana(context),
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: const Text('Salin'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E293B),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tombol WhatsApp Konfirmasi
                          ElevatedButton.icon(
                            onPressed: () => _launchWhatsAppConfirmation(context),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Konfirmasi Pembayaran via WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                              textStyle: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tombol Cek Status Perpanjangan
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.invalidate(tenantSubscriptionProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Memeriksa status langganan...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Cek Status Perpanjangan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tombol Logout & Catatan
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Akun akan dibuka otomatis setelah transfer diverifikasi.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(authControllerProvider).logout();
                                  if (context.mounted) {
                                    context.go('/login');
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE11D48),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: const Text(
                                  'Keluar Akun',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
