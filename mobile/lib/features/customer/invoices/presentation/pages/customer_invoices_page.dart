import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/invoice_provider.dart';
import '../../../../../data/models/invoice_model.dart';
import '../../../../../data/models/profile_model.dart';
import '../../../payment/presentation/widgets/payment_modal.dart';
import '../widgets/invoice_detail_modal.dart';

class CustomerInvoicesPage extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final String? highlightInvoiceId;

  const CustomerInvoicesPage({
    super.key,
    this.initialTabIndex = 0,
    this.highlightInvoiceId,
  });

  @override
  ConsumerState<CustomerInvoicesPage> createState() => _CustomerInvoicesPageState();
}

class _CustomerInvoicesPageState extends ConsumerState<CustomerInvoicesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update tab styles
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Check for highlightInvoiceId
    if (widget.highlightInvoiceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAndShowInvoiceDetail(widget.highlightInvoiceId!);
      });
    }
  }

  Future<void> _fetchAndShowInvoiceDetail(String invoiceId) async {
    try {
      final invoice = await ref.read(invoiceControllerProvider.notifier).getInvoiceById(invoiceId);
      final user = ref.read(currentUserProvider).value;
      if (mounted && user != null) {
        _showInvoiceDetail(invoice, user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail tagihan: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

          final invoicesAsync = ref.watch(customerInvoicesProvider(user.id!));

          return SafeArea(
            child: Column(
              children: [
                // Sticky Header & Search
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.go('/customer/dashboard'),
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                            ),
                            const Expanded(
                              child: Text(
                                'Riwayat Tagihan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF110E1B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40), // Balance the back button
                          ],
                        ),
                      ),

                      // Tabs
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFD6D1E6))),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(0, 'Dibayar'),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: _buildTabButton(1, 'Belum Dibayar'),
                            ),
                          ],
                        ),
                      ),

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.search, color: Color(0xFF625095)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: _tabController.index == 1
                                        ? 'Cari tagihan belum dibayar...'
                                        : 'Cari riwayat pembayaran...',
                                    hintStyle: const TextStyle(color: Color(0xFF625095)),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: const EdgeInsets.only(right: 16),
                                  ),
                                  style: const TextStyle(color: Color(0xFF110E1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: invoicesAsync.when(
                    data: (invoices) {
                      // Filter logic
                      final unpaid = invoices.where((i) =>
                          i.status == 'unpaid' ||
                          i.status == 'partially_paid' ||
                          i.status == 'installment').toList();
                      
                      final paid = invoices.where((i) => i.status == 'paid').toList();

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInvoiceList(paid, true, user),
                          _buildInvoiceList(unpaid, false, user),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTabButton(int index, String text) {
    final isActive = _tabController.index == index;
    return InkWell(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF110E1B) : const Color(0xFF625095),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<InvoiceModel> invoices, bool isPaidTab, user) {
    // Filter by search query
    final filteredInvoices = invoices.where((invoice) {
      final period = (invoice.invoicePeriod ?? '').toLowerCase();
      final amount = invoice.amount.toString();
      return period.contains(_searchQuery) || amount.contains(_searchQuery);
    }).toList();

    // Sort logic
    if (isPaidTab) {
      filteredInvoices.sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    } else {
      // Sort unpaid by period desc (assuming period string is comparable or use created_at if available)
      // For now, let's rely on the order from DB or basic string compare
      filteredInvoices.sort((a, b) => (b.invoicePeriod ?? '').compareTo(a.invoicePeriod ?? ''));
    }

    if (filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPaidTab ? Icons.history : Icons.receipt_long,
              size: 96,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPaidTab
                  ? 'Belum ada riwayat pembayaran'
                  : 'Tidak ada tagihan belum dibayar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index];
        final period = invoice.invoicePeriod ?? 'Periode tidak tersedia';
        
        if (isPaidTab) {
          // Paid Item Style
          final paidDate = invoice.paidAt != null
              ? DateFormat('d MMMM yyyy', 'id_ID').format(invoice.paidAt!)
              : 'Tanggal tidak tersedia';
          final amount = (invoice.amountPaid ?? 0) > 0 ? invoice.amountPaid! : invoice.amount;

          return InkWell(
            onTap: () => _showInvoiceDetail(invoice, user),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pembayaran $period',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            paidDate,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Unpaid Item Style
          final dueDate = invoice.dueDate != null
              ? DateFormat('d MMMM yyyy', 'id_ID').format(invoice.dueDate!)
              : 'Tanggal tidak tersedia';
          final amount = invoice.remainingAmount > 0 ? invoice.remainingAmount : invoice.amount;

          return Container(
            margin: const EdgeInsets.only(bottom: 0), // Border bottom style
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF9F8FB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF110E1B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      Text(
                        currencyFormat.format(amount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _showPaymentModal(context, [invoice], user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Bayar'),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _showPaymentModal(BuildContext context, List<InvoiceModel> invoices, user) {
    final totalAmount = invoices.fold(0.0, (sum, i) => sum + (i.remainingAmount > 0 ? i.remainingAmount : i.amount));
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

  void _showInvoiceDetail(InvoiceModel invoice, ProfileModel user) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final paidDate = invoice.paidAt != null
        ? DateFormat('EEEE, d MMMM yyyy, HH:mm', 'id_ID').format(invoice.paidAt!)
        : 'Tidak tersedia';
    final amount = (invoice.amountPaid ?? 0) > 0 ? invoice.amountPaid! : invoice.amount;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Expanded(
                      child: Text(
                        'Detail Pembayaran',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance back button
                  ],
                ),
              ),

              // LUNAS Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'LUNAS',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Customer Info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Pelanggan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Nama Pelanggan', user.fullName ?? '-'),
                    _buildDetailRow('ID Pelanggan', user.idpl ?? '-'),
                    _buildDetailRow('WhatsApp', user.whatsappNumber ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Periode Tagihan', invoice.invoicePeriod),
                    _buildDetailRow('Jumlah Tagihan', currencyFormat.format(amount)),
                    _buildDetailRow('Tanggal Bayar', paidDate),
                    _buildDetailRow('Metode Pembayaran', invoice.paymentMethod ?? 'Tidak diketahui'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(color: Color(0xFF625095), fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LUNAS',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF625095),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF110E1B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
