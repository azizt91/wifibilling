import '../../../../../core/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/invoice_model.dart';
import '../../../../../data/models/payment_method_model.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/invoice_provider.dart';
import '../../../../../data/providers/payment_provider.dart';
import '../providers/dashboard_provider.dart';

import '../../../payment/presentation/widgets/payment_modal.dart';

class CustomerDashboardPage extends ConsumerStatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  ConsumerState<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends ConsumerState<CustomerDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: dashboardAsync.when(
        data: (data) => _buildDashboardContent(context, ref, data.user, data.invoices),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardDataProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, WidgetRef ref, user, List<InvoiceModel> invoices) {
    return SafeArea(
      child: Column(
        children: [
          // Fixed Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildHeader(context, user),
          ),
          
          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                return ref.refresh(dashboardDataProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tagihan Card
                    _buildTagihanCard(context, invoices, user),
                    const SizedBox(height: 16),

                    // Paket Aktif Card
                    _buildPaketAktifCard(context, user),
                    const SizedBox(height: 16),

                    // Riwayat Pembayaran Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Pembayaran',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.go(Uri(path: '/customer/invoices', queryParameters: {'tab': '0'}).toString()),
                          child: const Text('Lihat Semua'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Riwayat Pembayaran List
                    _buildRiwayatList(context, invoices),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            AppAvatar(
              photoUrl: user?.photoUrl,
              name: user?.fullName,
              size: 40,
            ),
            const SizedBox(width: 12),
            Text(
              'Halo, ${user.fullName ?? 'Pelanggan'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Yakin ingin logout?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(authControllerProvider).logout();
              if (context.mounted) context.go('/login');
            }
          },
        ),
      ],
    );
  }

  Widget _buildTagihanCard(BuildContext context, List<InvoiceModel> invoices, user) {
    final unpaidInvoices = invoices.where((i) => i.status == 'unpaid').toList();
    final paidInvoices = invoices.where((i) => i.status == 'paid').toList();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // State 1: Arrears (Tunggakan)
    if (unpaidInvoices.isNotEmpty) {
      final totalTunggakan = unpaidInvoices.fold(0.0, (sum, i) => sum + i.amount);
      
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Tunggakan', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(currencyFormat.format(totalTunggakan), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${unpaidInvoices.length} tagihan belum dibayar', style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              ...unpaidInvoices.take(2).map((invoice) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.receipt_long, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tagihan ${invoice.invoicePeriod}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Text('Belum Dibayar', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    Text(currencyFormat.format(invoice.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showPaymentModal(context, ref, unpaidInvoices, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State 2: Paid (Lunas)
    if (paidInvoices.isNotEmpty) {
      // Sort by paidAt desc
      paidInvoices.sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
      final latestPaid = paidInvoices.first;

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Tagihan Bulan Ini', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(currencyFormat.format(latestPaid.amountPaid), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('Sudah Dibayar', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(
                      Uri(
                        path: '/customer/invoices',
                        queryParameters: {
                          'tab': '0',
                          'invoiceId': latestPaid.id,
                        },
                      ).toString(),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Lihat Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // State 3: Empty
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Tagihan Bulan Ini', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Rp 0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Tidak Ada Tagihan', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaketAktifCard(BuildContext context, user) {
    final installationDate = user.installationDate;
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final formattedDate =
        installationDate != null ? dateFormat.format(installationDate) : '-';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anda Berlangganan Sejak',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(formattedDate,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatList(BuildContext context, List<InvoiceModel> invoices) {
    final paidInvoices = invoices.where((i) => i.status == 'paid').toList();
    paidInvoices.sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    final recentPaid = paidInvoices.take(4).toList();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    if (recentPaid.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Belum ada riwayat pembayaran.', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: recentPaid.asMap().entries.map((entry) {
          final index = entry.key;
          final invoice = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pembayaran ${invoice.invoicePeriod}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              invoice.paidAt != null ? DateFormat('d MMM yyyy', 'id_ID').format(invoice.paidAt!) : '-',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(currencyFormat.format(invoice.amountPaid), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (index < recentPaid.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showPaymentModal(BuildContext context, WidgetRef ref, List<InvoiceModel> invoices, user) {
    final totalAmount = invoices.fold(0.0, (sum, i) => sum + i.amount);
    final periods = invoices.map((i) => i.invoicePeriod).join(', ');
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentModal(
        totalAmount: totalAmount,
        periods: periods,
        formattedAmount: currencyFormat.format(totalAmount),
        user: user,
      ),
    );
  }
}
