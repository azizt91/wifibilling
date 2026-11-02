import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_avatar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/dashboard_provider.dart';
import 'customer_edit_page.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final customerDetail = ref.watch(customerDetailProvider(widget.customerId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: customerDetail.when(
          data: (data) => _buildContent(context, data),
          loading: () => _buildLoadingSkeleton(context),
          error: (e, _) => _buildError(context, e.toString()),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final customer = data['customer'] as Map<String, dynamic>?;
    final invoices = data['invoices'] as List<dynamic>? ?? [];

    if (customer == null) {
      return _buildError(context, 'Data pelanggan tidak ditemukan');
    }

    final photoUrl = customer['photo_url'] ?? '';
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

    // Get unpaid invoices
    final unpaidInvoices = invoices.where((inv) => inv['status'] == 'unpaid').toList();

    return Column(
      children: [
        // Header
        _buildHeader(context, customer),
        // Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                _buildProfileSection(customer, photoUrl),
                // Detail Grid
                _buildDetailGrid(context, customer, currencyFormat, dateFormat),
                // Location Section
                if (customer['latitude'] != null && customer['longitude'] != null)
                  _buildLocationSection(customer),
                // Unpaid Bills Section
                if (unpaidInvoices.isNotEmpty)
                  _buildUnpaidBillsSection(unpaidInvoices, currencyFormat, customer['full_name'] ?? '-'),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> customer) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8FB),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              // Back Button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                splashRadius: 24,
              ),
              // Title
              const Expanded(
                child: Text(
                  'Detail Pelanggan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF110E1B),
                  ),
                ),
              ),
              // Action Buttons
              IconButton(
                onPressed: _isDeleting ? null : () => _showDeleteConfirmation(context, customer),
                icon: _isDeleting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                splashRadius: 24,
              ),
              IconButton(
                onPressed: () => _navigateToEdit(context, customer),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF110E1B)),
                splashRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(Map<String, dynamic> customer, String photoUrl) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            // Profile Avatar using AppAvatar (Default avatar support)
            AppAvatar(
              photoUrl: photoUrl,
              name: customer['full_name'],
              size: 96,
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              customer['full_name'] ?? '-',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF110E1B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // IDPL
            Text(
              customer['idpl'] ?? '-',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF625095),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailGrid(
    BuildContext context,
    Map<String, dynamic> customer,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isActive = customer['status'] == 'AKTIF';
    
    // Get package info
    final packageName = customer['package_name'] ?? 'Belum diatur';
    final packagePrice = customer['package_price'];
    
    // Date info
    String dateLabel = isActive ? 'TANGGAL PASANG' : 'TANGGAL CABUT';
    String dateValue;
    if (isActive) {
      dateValue = customer['installation_date'] != null
          ? dateFormat.format(DateTime.parse(customer['installation_date']))
          : '-';
    } else {
      dateValue = customer['churn_date'] != null
          ? dateFormat.format(DateTime.parse(customer['churn_date']))
          : 'Belum diset';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('IDPL', customer['idpl'] ?? '-')),
              Expanded(child: _buildDetailItem('NAMA', customer['full_name'] ?? '-')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildDetailItem('ALAMAT', customer['address'] ?? '-')),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildDetailItemWithAction(
                  'WHATSAPP',
                  customer['whatsapp_number'] ?? '-',
                  onTap: customer['whatsapp_number'] != null
                      ? () => _openWhatsApp(customer['whatsapp_number'])
                      : null,
                ),
              ),
              Expanded(child: _buildDetailItem('EMAIL', customer['email'] ?? '-')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildDetailItem('PAKET', packageName)),
              Expanded(
                child: _buildDetailItem(
                  'TAGIHAN',
                  packagePrice != null ? currencyFormat.format(packagePrice) : 'N/A',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'STATUS',
                  customer['status'] ?? '-',
                  valueColor: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                ),
              ),
              Expanded(child: _buildDetailItem(dateLabel, dateValue)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildDetailItem('JENIS PERANGKAT', customer['device_type'] ?? '-')),
              Expanded(child: _buildDetailItem('IP STATIC/PPOE', customer['ip_static_pppoe'] ?? '-')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF625095),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? const Color(0xFF110E1B),
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItemWithAction(
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF625095),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: onTap != null ? const Color(0xFF683FE4) : const Color(0xFF110E1B),
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> customer) {
    final lat = customer['latitude'];
    final lng = customer['longitude'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOKASI',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF625095),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$lat, $lng',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF110E1B),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openMaps(lat, lng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF15803D),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Buka Maps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpaidBillsSection(List<dynamic> unpaidInvoices, NumberFormat currencyFormat, String customerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Tagihan Belum Dibayar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF110E1B),
            ),
          ),
        ),
        ...unpaidInvoices.map((invoice) => _buildUnpaidBillItem(invoice, currencyFormat, customerName)),
      ],
    );
  }

  Widget _buildUnpaidBillItem(dynamic invoice, NumberFormat currencyFormat, String customerName) {
    final amount = invoice['amount'] ?? invoice['total_due'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF110E1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice['invoice_period'] ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF625095),
                  ),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCA8A04),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingSkeleton(BuildContext context) {
    return Column(
      children: [
        // Header Skeleton
        Container(
          color: const Color(0xFFF9F8FB),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                  ),
                  const Expanded(
                    child: Text(
                      'Detail Pelanggan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF110E1B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                ],
              ),
            ),
          ),
        ),
        // Content Skeleton with Shimmer
        Expanded(
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Skeleton
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 150,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Detail Grid Skeleton
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(6, (index) => _buildDetailRowSkeleton()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Column(
      children: [
        // Header
        Container(
          color: const Color(0xFFF9F8FB),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                  ),
                  const Expanded(
                    child: Text(
                      'Detail Pelanggan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF110E1B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
        // Error Content
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToEdit(BuildContext context, Map<String, dynamic> customer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerEditPage(customer: customer)),
    );
    if (result == true) {
      ref.invalidate(customerDetailProvider(widget.customerId));
    }
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text(
          'Apakah Anda yakin ingin menghapus pelanggan "${customer['full_name']}"?\n\n'
          'Tindakan ini akan menghapus:\n'
          '• Akun login\n'
          '• Data profil pelanggan\n'
          '• Semua riwayat tagihan\n\n'
          'Data yang dihapus TIDAK DAPAT dikembalikan!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCustomer(customer);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final customerId = customer['id'];
    final customerName = customer['full_name'] ?? 'Pelanggan';

    setState(() => _isDeleting = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Step 1: Delete all invoices
      await supabase.from('invoices').delete().eq('customer_id', customerId);

      // Step 2: Delete profile
      await supabase.from('profiles').delete().eq('id', customerId);

      // Step 3: Delete from Supabase Auth (using Edge Function)
      try {
        await supabase.functions.invoke('delete-user', body: {'user_id': customerId});
      } catch (e) {
        debugPrint('Warning: Auth delete error (continuing): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pelanggan "$customerName" berhasil dihapus')),
        );
        ref.invalidate(allCustomersProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus pelanggan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Clean phone number
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '62${cleanNumber.substring(1)}';
    }
    
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps(dynamic lat, dynamic lng) async {
    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
