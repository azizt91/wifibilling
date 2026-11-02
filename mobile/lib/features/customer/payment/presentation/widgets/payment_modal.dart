import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/profile_model.dart';
import '../../../../../data/providers/payment_method_provider.dart';
import '../../../../../data/providers/app_settings_provider.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';

class PaymentModal extends ConsumerStatefulWidget {
  final double totalAmount;
  final String periods;
  final String formattedAmount;
  final ProfileModel user;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    required this.periods,
    required this.formattedAmount,
    required this.user,
  });

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Invoice Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.indigo[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tagihan untuk:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text(widget.periods, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.formattedAmount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
            tabs: const [
              Tab(text: 'QRIS'),
              Tab(text: 'Transfer Manual'),
            ],
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // QRIS Tab
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Scan QR code di bawah ini menggunakan aplikasi pembayaran favorit Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        Image.asset(
                          'assets/images/qris.jpeg',
                          height: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 100, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('QRIS Image not found'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'QRIS ini statis. Pastikan jumlah transfer sesuai dengan tagihan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transfer Tab
                paymentMethodsAsync.when(
                  data: (methods) {
                    if (methods.isEmpty) {
                      return const Center(child: Text('Tidak ada metode transfer tersedia.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: methods.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final method = methods[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(method.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(method.accountNumber, style: const TextStyle(fontFamily: 'Monospace', fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('a.n. ${method.accountHolder}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.indigo),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: method.accountNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Nomor rekening ${method.accountNumber} disalin!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: ElevatedButton.icon(
              onPressed: _confirmPayment,
              icon: const Icon(Icons.chat),
              label: const Text('Konfirmasi via WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment() async {
    final message = '''Halo Admin Selinggonet, saya ingin mengkonfirmasi pembayaran tagihan:

- *Nama:* ${widget.user.fullName ?? widget.user.email}
- *ID Pelanggan:* ${widget.user.idpl ?? 'N/A'}
- *Periode:* ${widget.periods}
- *Jumlah:* ${widget.formattedAmount}

Saya sudah melakukan pembayaran. Mohon untuk diverifikasi. Terima kasih.''';

    try {
      final settings = await ref.read(appSettingsProvider.future);
      final whatsappNumber = settings?.whatsappNumber;

      if (whatsappNumber == null || whatsappNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nomor WhatsApp admin belum dikonfigurasi')),
          );
        }
        return;
      }

      await WhatsAppLauncher.launchWhatsApp(
        phone: whatsappNumber,
        message: message,
        onError: (errorMessage) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat konfigurasi: $e')),
        );
      }
    }
  }
}
