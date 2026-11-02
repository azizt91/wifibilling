import '../../../../../core/widgets/whatsapp_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/notification_provider.dart';
import '../../../../../core/widgets/printer_settings_modal.dart';
import '../../../../../data/providers/printer_provider.dart';
import '../../../../../core/widgets/broadcast_modal.dart';

// Invoice Model
class InvoiceModel {
  final String id; // UUID as String
  final String invoicePeriod;
  final double amount;
  final double totalDue;
  final double amountPaid;
  final String status;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String customerName;
  final String customerId;
  final String? customerIdpl;
  final String? customerWhatsapp;
  final int broadcastCount;

  InvoiceModel({
    required this.id,
    required this.invoicePeriod,
    required this.amount,
    required this.totalDue,
    required this.amountPaid,
    required this.status,
    this.paidAt,
    this.paymentMethod,
    required this.customerName,
    required this.customerId,
    this.customerIdpl,
    this.customerWhatsapp,
    this.broadcastCount = 0,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      invoicePeriod: json['invoice_period']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      totalDue: (json['total_due'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'unpaid',
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      paymentMethod: json['payment_method']?.toString(),
      customerName: profile?['full_name']?.toString() ?? '-',
      customerId: json['customer_id']?.toString() ?? '',
      customerIdpl: profile?['idpl']?.toString(),
      customerWhatsapp: profile?['whatsapp_number']?.toString(),
      broadcastCount: (json['broadcast_count'] as num?)?.toInt() ?? 0,
    );
  }

  InvoiceModel copyWith({
    String? id,
    String? invoicePeriod,
    double? amount,
    double? totalDue,
    double? amountPaid,
    String? status,
    DateTime? paidAt,
    String? paymentMethod,
    String? customerName,
    String? customerId,
    String? customerIdpl,
    String? customerWhatsapp,
    int? broadcastCount,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoicePeriod: invoicePeriod ?? this.invoicePeriod,
      amount: amount ?? this.amount,
      totalDue: totalDue ?? this.totalDue,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      customerIdpl: customerIdpl ?? this.customerIdpl,
      customerWhatsapp: customerWhatsapp ?? this.customerWhatsapp,
      broadcastCount: broadcastCount ?? this.broadcastCount,
    );
  }
}

// Providers
final invoicesFilterProvider = StateProvider<String>((ref) => 'unpaid');
final invoicesSearchProvider = StateProvider<String>((ref) => '');
final invoicesPeriodFilterProvider = StateProvider<String?>((ref) => null); // Filter periode: "Desember 2025"

final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final filter = ref.watch(invoicesFilterProvider);
  final search = ref.watch(invoicesSearchProvider);
  final periodFilter = ref.watch(invoicesPeriodFilterProvider);

  var query = supabase.from('invoices').select('*, profiles(full_name, idpl, whatsapp_number)');

  if (filter == 'unpaid') {
    query = query.eq('status', 'unpaid');
  } else if (filter == 'installment') {
    query = query.eq('status', 'partially_paid');
  } else if (filter == 'paid') {
    query = query.eq('status', 'paid');
  }

  // Filter berdasarkan periode jika ada (dari dashboard)
  if (periodFilter != null && periodFilter.isNotEmpty) {
    query = query.eq('invoice_period', periodFilter);
  }

  // Sort by paid_at for paid invoices (newest payment first), otherwise by created_at
  final orderColumn = filter == 'paid' ? 'paid_at' : 'created_at';
  final response = await query.order(orderColumn, ascending: false);
  
  var invoices = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();

  if (search.isNotEmpty) {
    invoices = invoices.where((inv) =>
      inv.customerName.toLowerCase().contains(search.toLowerCase()) ||
      inv.invoicePeriod.toLowerCase().contains(search.toLowerCase())
    ).toList();
  }

  return invoices;
});

class AdminInvoicesPage extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  final int? initialMonth;
  final int? initialYear;
  const AdminInvoicesPage({super.key, this.initialStatusFilter, this.initialMonth, this.initialYear});
  @override
  ConsumerState<AdminInvoicesPage> createState() => _AdminInvoicesPageState();
}

class _AdminInvoicesPageState extends ConsumerState<AdminInvoicesPage> {
  final _searchController = TextEditingController();
  String _currentFilter = 'unpaid';
  final Set<String> _selectedInvoiceIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    // Set initial filter from parameter
    if (widget.initialStatusFilter != null) {
      _currentFilter = widget.initialStatusFilter!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(invoicesFilterProvider.notifier).state = widget.initialStatusFilter!;
        
        // Set period filter jika bulan dan tahun diberikan
        if (widget.initialMonth != null && widget.initialMonth! > 0 && widget.initialYear != null) {
          final namaBulan = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
          final periodFilter = '${namaBulan[widget.initialMonth!]} ${widget.initialYear}';
          ref.read(invoicesPeriodFilterProvider.notifier).state = periodFilter;
        } else {
          // Reset period filter jika tidak ada filter bulan/tahun
          ref.read(invoicesPeriodFilterProvider.notifier).state = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _currentFilter = filter;
      _selectedInvoiceIds.clear();
    });
    ref.read(invoicesFilterProvider.notifier).state = filter;
  }

  void _onSearchChanged(String value) {
    ref.read(invoicesSearchProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(invoicesSearchProvider.notifier).state = '';
  }


  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(invoicesProvider),
                child: invoices.when(
                  data: (data) => _buildInvoiceList(data),
                  loading: () => _buildSkeletonList(),
                  error: (e, _) => _buildError(e.toString()),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _currentFilter == 'unpaid'
            ? FloatingActionButton(
                onPressed: _createInvoices,
                backgroundColor: const Color(0xFF683FE4),
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    final periodFilter = ref.watch(invoicesPeriodFilterProvider);
    final printerState = ref.watch(printerProvider);
    
    return Container(
      color: const Color(0xFFF9F8FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text('Tagihan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
                  IconButton(
                    icon: Icon(
                      printerState.isConnected ? Icons.print : Icons.print_outlined,
                      color: printerState.isConnected ? const Color(0xFF22C55E) : const Color(0xFF683FE4),
                    ),
                    tooltip: 'Pengaturan Printer Bluetooth',
                    onPressed: () => PrinterSettingsModal.show(context),
                  ),
                ],
              ),
            ),
            // Period filter info (jika ada filter dari dashboard)
            if (periodFilter != null && periodFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF683FE4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF683FE4).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 16, color: Color(0xFF683FE4)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filter: $periodFilter',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF683FE4)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(invoicesPeriodFilterProvider.notifier).state = null;
                        },
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF683FE4)),
                      ),
                    ],
                  ),
                ),
              ),
            // Filter Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _buildFilterPill('unpaid', 'Belum Dibayar'),
                  const SizedBox(width: 8),
                  _buildFilterPill('installment', 'Cicilan'),
                  const SizedBox(width: 8),
                  _buildFilterPill('paid', 'Dibayar'),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8F3),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF625095), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF110E1B)),
                        cursorColor: const Color(0xFF625095),
                        decoration: const InputDecoration(
                          hintText: 'Cari tagihan...',
                          hintStyle: TextStyle(color: Color(0xFF625095), fontSize: 16),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clearSearch,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String value, String label) {
    final isActive = _currentFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onFilterChanged(value),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF683FE4) : const Color(0xFFEAE8F3),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF110E1B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<InvoiceModel> data) {
    if (data.isEmpty) {
      String message = 'Tidak ada tagihan ditemukan';
      if (_currentFilter == 'unpaid') message = 'Tidak ada tagihan belum dibayar';
      if (_currentFilter == 'installment') message = 'Tidak ada tagihan cicilan';
      if (_currentFilter == 'paid') message = 'Tidak ada tagihan yang dibayar';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 96, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            const Text('Coba ubah filter atau kata kunci pencarian', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_currentFilter == 'unpaid') _buildBulkActionBar(data),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: data.length,
            itemBuilder: (_, i) => _buildInvoiceItem(data[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceItem(InvoiceModel invoice) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final pillColor = _getMonthPillColor(invoice.invoicePeriod);

    // For paid tab, make entire item clickable
    if (_currentFilter == 'paid') {
      return _buildPaidInvoiceItem(invoice, currencyFormat, pillColor);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          if (_currentFilter == 'unpaid')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _selectedInvoiceIds.contains(invoice.id),
                  activeColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedInvoiceIds.add(invoice.id);
                      } else {
                        _selectedInvoiceIds.remove(invoice.id);
                      }
                    });
                  },
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: pillColor['bg'], borderRadius: BorderRadius.circular(12)),
                  child: Text(invoice.invoicePeriod, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: pillColor['text'])),
                ),
              ],
            ),
          ),
          if (_currentFilter == 'unpaid') ...[
            // Broadcast count indicator icons (1st & 2nd WhatsApp icons)
            Row(
              children: [
                WhatsAppIcon(
                  size: 14,
                  color: invoice.broadcastCount >= 1 ? const Color(0xFF22C55E) : Colors.grey.shade300,
                ),
                const SizedBox(width: 3),
                WhatsAppIcon(
                  size: 14,
                  color: invoice.broadcastCount >= 2 ? const Color(0xFF22C55E) : Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(width: 8),
            // WhatsApp button
            GestureDetector(
              onTap: () => _sendWhatsApp(invoice),
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
                child: const Center(
                  child: WhatsAppIcon(size: 16, color: Colors.white),
                ),
              ),
            ),
            // Tombol Bayar Lunas Langsung (Sesuai Web: LUNAS)
            GestureDetector(
              onTap: () => _showPaymentDialog(invoice, isInstallment: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LUNAS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF110E1B),
                  ),
                ),
              ),
            ),
            // Titik 3 (⋮) Menu Options: Bayar Cicilan & Hapus Tagihan
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'cicil') {
                  _showPaymentDialog(invoice, isInstallment: true);
                } else if (val == 'delete') {
                  _confirmSingleDelete(invoice);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'cicil',
                  height: 38,
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text('Bayar Cicilan', style: TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'delete',
                  height: 38,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Hapus Tagihan', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (_currentFilter == 'installment') ...[
            // WhatsApp button
            GestureDetector(
              onTap: () => _sendWhatsApp(invoice),
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
                child: const Center(
                  child: WhatsAppIcon(size: 16, color: Colors.white),
                ),
              ),
            ),
            // Cicil button for installment tab
            GestureDetector(
              onTap: () => _showPaymentDialog(invoice, isInstallment: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: const Color(0xFFCA8A04), borderRadius: BorderRadius.circular(8)),
                child: const Text('Cicil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            // Lunas button
            GestureDetector(
              onTap: () => _showPaymentDialog(invoice, isInstallment: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
                child: const Text('Lunas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaidInvoiceItem(InvoiceModel invoice, NumberFormat currencyFormat, Map<String, Color> pillColor) {
    // Format paid date
    String dayStr = '--';
    String monthStr = '';
    String yearStr = '';
    
    if (invoice.paidAt != null) {
      dayStr = invoice.paidAt!.day.toString().padLeft(2, '0');
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      monthStr = months[invoice.paidAt!.month];
      yearStr = invoice.paidAt!.year.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          // Date column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(dayStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                Text(monthStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(yearStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Customer info - clickable for detail
          Expanded(
            child: GestureDetector(
              onTap: () => _showInvoiceDetail(invoice),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: pillColor['bg'], borderRadius: BorderRadius.circular(12)),
                    child: Text(invoice.invoicePeriod, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: pillColor['text'])),
                  ),
                ],
              ),
            ),
          ),
          // Status and method - clickable for detail
          GestureDetector(
            onTap: () => _showInvoiceDetail(invoice),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('LUNAS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                const SizedBox(height: 2),
                Text(invoice.paymentMethod ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Print receipt button
          GestureDetector(
            onTap: () => _printReceipt(invoice),
            child: Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF683FE4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.print, color: Color(0xFF683FE4), size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // Revert payment button
          GestureDetector(
            onTap: () => _confirmRevertPayment(invoice),
            child: Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              child: const Icon(Icons.replay, color: Color(0xFFF97316), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getMonthPillColor(String period) {
    final month = period.split(' ').first;
    switch (month) {
      case 'Januari': return {'bg': const Color(0xFFE0F2FE), 'text': const Color(0xFF0369A1)};
      case 'Februari': return {'bg': const Color(0xFFDBEAFE), 'text': const Color(0xFF1D4ED8)};
      case 'Maret': return {'bg': const Color(0xFFD1FAE5), 'text': const Color(0xFF047857)};
      case 'April': return {'bg': const Color(0xFFDCFCE7), 'text': const Color(0xFF15803D)};
      case 'Mei': return {'bg': const Color(0xFFECFCCB), 'text': const Color(0xFF4D7C0F)};
      case 'Juni': return {'bg': const Color(0xFFFEF9C3), 'text': const Color(0xFFA16207)};
      case 'Juli': return {'bg': const Color(0xFFFEF3C7), 'text': const Color(0xFFB45309)};
      case 'Agustus': return {'bg': const Color(0xFFFFEDD5), 'text': const Color(0xFFC2410C)};
      case 'September': return {'bg': const Color(0xFFFEE2E2), 'text': const Color(0xFFDC2626)};
      case 'Oktober': return {'bg': const Color(0xFFFFE4E6), 'text': const Color(0xFFBE123C)};
      case 'November': return {'bg': const Color(0xFFEDE9FE), 'text': const Color(0xFF7C3AED)};
      case 'Desember': return {'bg': const Color(0xFFE0E7FF), 'text': const Color(0xFF4338CA)};
      default: return {'bg': const Color(0xFFF3F4F6), 'text': const Color(0xFF374151)};
    }
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: 10,
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(
            children: [
              // Date column for paid tab
              if (_currentFilter == 'paid') ...[
                Column(
                  children: [
                    Container(width: 32, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Container(width: 28, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 2),
                    Container(width: 36, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              // Customer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 140, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
              ),
              // Action buttons based on filter
              if (_currentFilter == 'unpaid') ...[
                Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                Container(width: 45, height: 32, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                Container(width: 90, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ] else if (_currentFilter == 'installment') ...[
                Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                Container(width: 45, height: 32, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                Container(width: 55, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ] else ...[
                // Paid tab - status and method
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(width: 50, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Container(width: 60, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
                const SizedBox(width: 6),
                Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text('Gagal memuat data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(invoicesProvider),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4), foregroundColor: Colors.white),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp(InvoiceModel invoice) async {
    if (invoice.customerWhatsapp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WhatsApp tidak tersedia')));
      return;
    }

    String phone = invoice.customerWhatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final message = 'Informasi Tagihan WiFi Anda\n\n'
        'Hai Bapak/Ibu ${invoice.customerName},\n'
        'ID Pelanggan: ${invoice.customerIdpl ?? "-"}\n\n'
        'Informasi tagihan Bapak/Ibu bulan ini adalah:\n'
        'Jumlah Tagihan: ${currencyFormat.format(invoice.amount)}\n'
        'Periode Tagihan: ${invoice.invoicePeriod}\n\n'
        'Bayar tagihan Anda di salah satu rekening di bawah ini:\n'
        '• Seabank 901307925714 An. TAUFIQ AZIZ\n'
        '• BCA 3621053653 An. TAUFIQ AZIZ\n'
        '• BSI 7211806138 An. TAUFIQ AZIZ\n'
        '• Dana 089609497390 An. TAUFIQ AZIZ\n\n'
        'Terima kasih atas kepercayaan Anda menggunakan layanan kami.\n'
        '_____________________________\n'
        '*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.';

    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showPaymentDialog(InvoiceModel invoice, {bool isInstallment = false}) async {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String? selectedMethod;
    // Jika cicilan, kosongkan field. Jika bayar penuh, isi dengan total
    final amountController = TextEditingController(text: isInstallment ? '' : invoice.amount.toInt().toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isInstallment ? 'Bayar Cicilan' : 'Bayar Lunas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pelanggan: ${invoice.customerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('Periode: ${invoice.invoicePeriod}'),
              Text('Total Tagihan: ${currencyFormat.format(invoice.totalDue > 0 ? invoice.totalDue : invoice.amount)}'),
              if (invoice.amountPaid > 0) Text('Sudah Dibayar: ${currencyFormat.format(invoice.amountPaid)}', style: const TextStyle(color: Color(0xFF22C55E))),
              Text('Sisa: ${currencyFormat.format(invoice.amount)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFCA8A04))),
              const SizedBox(height: 16),
              Text(isInstallment ? 'Jumlah Cicilan:' : 'Jumlah Bayar:', style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: isInstallment,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: isInstallment ? 'Masukkan jumlah cicilan' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['cash', 'transfer', 'qris', 'e-wallet'].map((method) {
                  final isSelected = selectedMethod == method;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedMethod = method),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF683FE4) : const Color(0xFFEAE8F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        method == 'e-wallet' ? 'E-Wallet' : method[0].toUpperCase() + method.substring(1),
                        style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF110E1B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: selectedMethod == null ? null : () {
                final inputAmount = double.tryParse(amountController.text) ?? 0;
                if (inputAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan jumlah yang valid')));
                  return;
                }
                if (inputAmount > invoice.amount) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah melebihi sisa tagihan')));
                  return;
                }
                Navigator.pop(ctx, {
                  'amount': inputAmount,
                  'method': selectedMethod,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4)),
              child: const Text('Bayar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _processPayment(invoice, result['amount'], result['method']);
    }
  }

  Future<void> _processPayment(InvoiceModel invoice, double amount, String method) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      final newAmountPaid = invoice.amountPaid + amount;
      final remaining = invoice.totalDue - newAmountPaid;

      String newStatus;
      bool isFullyPaid = false;
      if (remaining <= 0) {
        newStatus = 'paid';
        isFullyPaid = true;
      } else {
        newStatus = 'partially_paid';
      }

      await supabase.from('invoices').update({
        'status': newStatus,
        'amount_paid': newAmountPaid,
        'amount': remaining > 0 ? remaining : 0,
        'payment_method': method,
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', invoice.id);

      ref.invalidate(invoicesProvider);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(isFullyPaid ? 'Tagihan berhasil dilunasi' : 'Pembayaran cicilan berhasil'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );

      final updatedInvoice = invoice.copyWith(
        status: newStatus,
        amountPaid: newAmountPaid,
        amount: remaining > 0 ? remaining : 0,
        paymentMethod: method,
        paidAt: DateTime.now(),
      );

      // Dialog penawaran cetak struk kasir
      final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                SizedBox(width: 8),
                Text('Pembayaran Berhasil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Pembayaran tagihan ${invoice.customerName} sebesar ${currencyFormat.format(amount)} telah dicatat.\n\nApakah Anda ingin mencetak struk kasir sekarang?',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Nanti Saja', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _printReceipt(
                    updatedInvoice,
                    customPaidAmount: newAmountPaid,
                    customMethod: method,
                    customStatus: newStatus,
                  );
                },
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Cetak Struk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF683FE4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      }

      // Add payment notification for admins
      await _addPaymentNotification(invoice, amount, method, isFullyPaid);

      // Send WhatsApp notification if fully paid
      if (isFullyPaid && invoice.customerWhatsapp != null && invoice.customerWhatsapp!.isNotEmpty) {
        await _sendPaymentNotification(invoice, amount, method);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal memproses pembayaran: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _addPaymentNotification(InvoiceModel invoice, double amount, String method, bool isFullyPaid) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider).valueOrNull;
      final adminName = user?.fullName ?? 'Admin';
      
      // Call RPC function to add payment notification
      // Parameters must match database function: customer_name, customer_idpl, invoice_period, amount (numeric), admin_name
      await supabase.rpc('add_payment_notification', params: {
        'customer_name': invoice.customerName,
        'customer_idpl': invoice.customerIdpl ?? '-',
        'invoice_period': invoice.invoicePeriod,
        'amount': amount, // Send as numeric, not formatted string
        'admin_name': adminName,
      });
      
      // Invalidate notification providers to refresh badge
      ref.invalidate(notificationsProvider);
    } catch (e) {
      debugPrint('Failed to add payment notification: $e');
    }
  }

  Future<void> _sendPaymentNotification(InvoiceModel invoice, double amount, String method) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // Check if auto notification is enabled
      final autoNotifResult = await supabase
          .from('whatsapp_settings')
          .select('setting_value')
          .eq('setting_key', 'auto_notification_enabled')
          .maybeSingle();

      if (autoNotifResult == null || autoNotifResult['setting_value'] != 'true') {
        return; // Auto notification disabled
      }

      // Get WhatsApp settings
      final settingsResult = await supabase.from('whatsapp_settings').select('*');
      final settings = <String, String>{};
      for (final s in settingsResult) {
        settings[s['setting_key']] = s['setting_value']?.toString() ?? '';
      }

      // Get customer email using RPC function
      String customerEmail = 'email_login_anda';
      try {
        final emailResult = await supabase.rpc('get_user_email', params: {'user_id': invoice.customerId});
        if (emailResult != null) {
          customerEmail = emailResult.toString();
        }
      } catch (e) {
        debugPrint('Failed to get customer email: $e');
      }

      // Format phone number
      String phone = invoice.customerWhatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      }

      // Get payment method text
      final methodText = {
        'cash': 'Tunai',
        'transfer': 'Transfer Bank',
        'e-wallet': 'E-Wallet',
        'qris': 'QRIS',
      }[method] ?? 'Tunai';

      // Get template
      final template = settings['template_payment_full'] ?? 
          'Halo {nama_pelanggan}, pembayaran tagihan periode {periode} sebesar {jumlah_dibayar} telah diterima. Terima kasih!';

      final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      
      // Replace variables
      final message = template
          .replaceAll('{nama_pelanggan}', invoice.customerName)
          .replaceAll('{idpl}', invoice.customerIdpl ?? '-')
          .replaceAll('{periode}', invoice.invoicePeriod)
          .replaceAll('{total_tagihan}', currencyFormat.format(invoice.totalDue))
          .replaceAll('{jumlah_dibayar}', currencyFormat.format(amount))
          .replaceAll('{sisa_tagihan}', currencyFormat.format(0))
          .replaceAll('{metode_pembayaran}', methodText)
          .replaceAll('{app_url}', settings['app_url'] ?? '')
          .replaceAll('{email_pelanggan}', customerEmail);

      // Call Supabase Edge Function
      await supabase.functions.invoke('send-whatsapp-notification', body: {
        'target': phone,
        'message': message,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikasi WhatsApp terkirim'), backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (e) {
      // Silent fail for notification - payment already successful
      debugPrint('Failed to send WhatsApp notification: $e');
    }
  }

  Future<void> _createInvoices() async {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    final monthOptions = [
      {'val': 1, 'name': 'Januari'},
      {'val': 2, 'name': 'Februari'},
      {'val': 3, 'name': 'Maret'},
      {'val': 4, 'name': 'April'},
      {'val': 5, 'name': 'Mei'},
      {'val': 6, 'name': 'Juni'},
      {'val': 7, 'name': 'Juli'},
      {'val': 8, 'name': 'Agustus'},
      {'val': 9, 'name': 'September'},
      {'val': 10, 'name': 'Oktober'},
      {'val': 11, 'name': 'November'},
      {'val': 12, 'name': 'Desember'},
    ];

    final yearOptions = List.generate(5, (i) => now.year - 1 + i);

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.receipt_long, color: Color(0xFF683FE4)),
                  SizedBox(width: 8),
                  Text('Buat Tagihan Bulanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih periode tagihan yang ingin dibuat:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: monthOptions.map((m) {
                            return DropdownMenuItem<int>(
                              value: m['val'] as int,
                              child: Text(m['name'] as String),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedMonth = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Tahun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          items: yearOptions.map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedYear = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tagihan akan dibuat untuk semua pelanggan aktif yang belum memiliki tagihan pada periode tersebut.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, {'month': selectedMonth, 'year': selectedYear}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF683FE4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Buat Tagihan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    await _handleCreateInvoicesForPeriod(result['month']!, result['year']!);
  }

  Future<void> _handleCreateInvoicesForPeriod(int monthIndex, int targetYear) async {
    const monthNames = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final targetMonthName = monthNames[monthIndex];
    final targetPeriod = '$targetMonthName $targetYear';

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 16),
            Text('Membuat tagihan untuk $targetPeriod...'),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Ambil semua pelanggan aktif yang punya paket
      final activeProfilesRes = await supabase
          .from('profiles')
          .select('id, package_id, tenant_id, packages(price)')
          .eq('status', 'AKTIF')
          .inFilter('role', ['USER', 'pelanggan', 'user'])
          .not('package_id', 'is', null);

      final activeProfiles = List<Map<String, dynamic>>.from(activeProfilesRes as List);

      if (activeProfiles.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Tidak ada pelanggan aktif yang ditemukan.'),
            backgroundColor: Color(0xFFCA8A04),
          ),
        );
        return;
      }

      // 2. Cek tagihan yang sudah ada untuk periode ini
      final existingInvoicesRes = await supabase
          .from('invoices')
          .select('customer_id')
          .ilike('invoice_period', targetPeriod);

      final existingInvoices = List<Map<String, dynamic>>.from(existingInvoicesRes as List);
      final existingCustomerIds = existingInvoices.map((e) => e['customer_id'].toString()).toSet();

      // 3. Filter pelanggan yang BELUM punya tagihan di periode tersebut
      final profilesToCreate = activeProfiles.where((p) => !existingCustomerIds.contains(p['id'].toString())).toList();

      if (profilesToCreate.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Semua pelanggan aktif sudah memiliki tagihan untuk periode $targetPeriod.'),
            backgroundColor: const Color(0xFF3B82F6),
          ),
        );
        return;
      }

      // 4. Hitung tanggal jatuh tempo (tanggal 10 bulan berikutnya)
      final nextMonthDate = DateTime(targetYear, monthIndex + 1, 10);
      final dueDateStr = DateFormat('yyyy-MM-dd').format(nextMonthDate);

      // 5. Siapkan payload
      final newInvoicesPayload = profilesToCreate.map((p) {
        final pkg = p['packages'];
        final price = (pkg != null && pkg['price'] != null) ? (pkg['price'] as num).toDouble() : 0.0;
        final map = <String, dynamic>{
          'customer_id': p['id'],
          'package_id': p['package_id'],
          'invoice_period': targetPeriod,
          'amount': price,
          'total_due': price,
          'amount_paid': 0,
          'status': 'unpaid',
          'due_date': dueDateStr,
        };
        if (p['tenant_id'] != null) {
          map['tenant_id'] = p['tenant_id'];
        }
        return map;
      }).toList();

      // 6. Insert data ke tabel invoices
      final insertRes = await supabase.from('invoices').insert(newInvoicesPayload).select();
      final insertedCount = (insertRes as List).length;

      scaffoldMessenger.hideCurrentSnackBar();
      ref.invalidate(invoicesProvider);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Berhasil membuat $insertedCount tagihan baru untuk periode $targetPeriod.'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal membuat tagihan: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _confirmRevertPayment(InvoiceModel invoice) async {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yakin ingin membatalkan pembayaran untuk:'),
            const SizedBox(height: 12),
            Text('Pelanggan: ${invoice.customerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('Periode: ${invoice.invoicePeriod}'),
            Text('Jumlah: ${currencyFormat.format(invoice.totalDue)}'),
            const SizedBox(height: 12),
            const Text('Status akan dikembalikan ke "Belum Dibayar".', style: TextStyle(color: Color(0xFFF97316), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final supabase = ref.read(supabaseClientProvider);
      
      await supabase.from('invoices').update({
        'status': 'unpaid',
        'amount_paid': 0,
        'amount': invoice.totalDue,
        'payment_method': null,
        'paid_at': null,
      }).eq('id', invoice.id);

      ref.invalidate(invoicesProvider);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Pembayaran berhasil dibatalkan'), backgroundColor: Color(0xFFF97316)),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal membatalkan pembayaran: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _showInvoiceDetail(InvoiceModel invoice) async {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('d MMMM yyyy, HH:mm', 'id_ID');

    // Fetch payment history using RPC
    List<Map<String, dynamic>> paymentHistory = [];
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.rpc('get_payment_history', params: {'p_invoice_id': invoice.id});
      
      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data != null && data['payment_history'] != null) {
          paymentHistory = List<Map<String, dynamic>>.from(data['payment_history']);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch payment history: $e');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
                        SizedBox(width: 8),
                        Text('LUNAS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Pelanggan', invoice.customerName),
                    _buildDetailRow('ID Pelanggan', invoice.customerIdpl ?? '-'),
                    _buildDetailRow('Periode', invoice.invoicePeriod),
                    _buildDetailRow('Total Tagihan', currencyFormat.format(invoice.totalDue)),
                    _buildDetailRow('Tanggal Lunas', invoice.paidAt != null ? dateFormat.format(invoice.paidAt!) : '-'),
                    _buildDetailRow('Metode Terakhir', invoice.paymentMethod ?? '-'),
                    
                    // Payment History Section
                    if (paymentHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Riwayat Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
                      const SizedBox(height: 12),
                      ...paymentHistory.map((payment) => _buildPaymentHistoryItem(payment, currencyFormat)),
                    ],
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _printReceipt(invoice);
                      },
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Cetak Struk'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF683FE4),
                        side: const BorderSide(color: Color(0xFF683FE4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF683FE4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tutup', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryItem(Map<String, dynamic> payment, NumberFormat currencyFormat) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final method = payment['payment_method']?.toString() ?? '-';
    final admin = payment['admin_name']?.toString() ?? '-';
    final note = payment['note']?.toString() ?? '';
    
    // Parse date
    String dateStr = '-';
    if (payment['paid_at'] != null) {
      try {
        final date = DateTime.parse(payment['paid_at'].toString());
        dateStr = DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);
      } catch (e) {
        dateStr = payment['paid_at'].toString();
      }
    }

    final methodText = {
      'cash': 'Tunai',
      'transfer': 'Transfer',
      'e-wallet': 'E-Wallet',
      'qris': 'QRIS',
    }[method] ?? method;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currencyFormat.format(amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(8)),
                child: Text(methodText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF7C3AED))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('Diproses oleh: $admin', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.note_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(child: Text(note, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkActionBar(List<InvoiceModel> data) {
    final isAllSelected = data.isNotEmpty && _selectedInvoiceIds.length == data.length;
    final selectedCount = _selectedInvoiceIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Checkbox Pilih Semua
          InkWell(
            onTap: () {
              setState(() {
                if (isAllSelected) {
                  _selectedInvoiceIds.clear();
                } else {
                  _selectedInvoiceIds.addAll(data.map((e) => e.id));
                }
              });
            },
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isAllSelected,
                    activeColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedInvoiceIds.addAll(data.map((e) => e.id));
                        } else {
                          _selectedInvoiceIds.clear();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Semua',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF110E1B)),
                ),
              ],
            ),
          ),

          // Action Buttons saat ada tagihan dicentang (Compact & Anti-Overflow)
          if (selectedCount > 0)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tombol Hapus Massal
                    ElevatedButton.icon(
                      onPressed: () => _confirmBulkDelete(selectedCount),
                      icon: const Icon(Icons.delete_outline, size: 13),
                      label: Text('Hapus ($selectedCount)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Broadcast Massal
                    ElevatedButton.icon(
                      onPressed: () => _openBroadcastModal(data),
                      icon: const WhatsAppIcon(size: 13, color: Colors.white),
                      label: Text('Broadcast ($selectedCount)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Hapus single tagihan via Menu Titik Tiga (⋮)
  Future<void> _confirmSingleDelete(InvoiceModel invoice) async {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Hapus Tagihan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda YAKIN ingin menghapus tagihan periode ${invoice.invoicePeriod} milik "${invoice.customerName}" (${currencyFormat.format(invoice.amount)})?\n\nTagihan yang dihapus tidak dapat dikembalikan.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus Tagihan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Menghapus tagihan...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('invoices')
          .delete()
          .eq('id', invoice.id)
          .eq('status', 'unpaid');

      setState(() {
        _selectedInvoiceIds.remove(invoice.id);
      });

      ref.invalidate(invoicesProvider);

      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Tagihan "${invoice.customerName}" berhasil dihapus.'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tagihan: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _confirmBulkDelete(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Hapus Tagihan Massal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda YAKIN ingin menghapus $count tagihan terpilih?\n\nPERINGATAN: Tagihan yang dihapus akan hilang secara permanen dari sistem!',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus $count Tagihan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final idsToDelete = _selectedInvoiceIds.toList();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menghapus $count tagihan...'),
          duration: const Duration(seconds: 2),
        ),
      );

      await supabase
          .from('invoices')
          .delete()
          .inFilter('id', idsToDelete)
          .eq('status', 'unpaid');

      setState(() {
        _selectedInvoiceIds.clear();
      });

      ref.invalidate(invoicesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil menghapus $count tagihan.'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tagihan: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _openBroadcastModal(List<InvoiceModel> allInvoices) {
    final selectedList = allInvoices.where((inv) => _selectedInvoiceIds.contains(inv.id)).toList();
    if (selectedList.isEmpty) return;

    BroadcastModal.show(
      context,
      selectedInvoices: selectedList,
      onCompleted: () {
        setState(() => _selectedInvoiceIds.clear());
        ref.invalidate(invoicesProvider);
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF625095))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    InvoiceModel invoice, {
    double? customPaidAmount,
    String? customMethod,
    String? customStatus,
  }) async {
    final printerService = ref.read(thermalPrinterServiceProvider);
    final printerState = ref.read(printerProvider);

    if (!printerState.isConnected) {
      final autoConnected = await printerService.autoConnect();
      if (!autoConnected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer belum terhubung. Hubungkan printer di menu Printer.'),
            backgroundColor: Colors.orange,
          ),
        );
        PrinterSettingsModal.show(context);
        return;
      }
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengirim data ke printer thermal...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Ambil identitas tenant & footer struk secara dinamis
      final supabase = ref.read(supabaseClientProvider);
      String? tenantName;
      String? tenantPhone;
      String? tenantAddress;
      String? receiptFooter = printerService.receiptFooter;

      try {
        final settings = await supabase
            .from('app_settings')
            .select('app_name, whatsapp_number, office_address')
            .limit(1)
            .maybeSingle();
        if (settings != null) {
          final appName = settings['app_name']?.toString().trim();
          if (appName != null && appName.isNotEmpty && appName != 'WiFi Billing System') {
            tenantName = appName;
          }
          tenantPhone = settings['whatsapp_number']?.toString().trim();
          tenantAddress = settings['office_address']?.toString().trim();
        }

        if (tenantName == null || tenantName.isEmpty) {
          final tenant = await supabase
              .from('tenants')
              .select('name')
              .limit(1)
              .maybeSingle();
          if (tenant != null && tenant['name'] != null) {
            final tName = tenant['name'].toString().trim();
            if (tName.isNotEmpty) tenantName = tName;
          }
        }

        // Ambil catatan footer khusus struk dari whatsapp_settings jika belum ada di lokal
        final footerRow = await supabase
            .from('whatsapp_settings')
            .select('setting_value')
            .eq('setting_key', 'receipt_footer')
            .maybeSingle();
        if (footerRow != null && footerRow['setting_value'] != null) {
          final val = footerRow['setting_value'].toString().trim();
          if (val.isNotEmpty) {
            receiptFooter = val;
          }
        }
      } catch (e) {
        debugPrint('Error getting tenant settings for receipt: $e');
      }

      final actualStatus = customStatus ?? invoice.status;
      final actualPaid = customPaidAmount ?? (invoice.amountPaid > 0 ? invoice.amountPaid : invoice.totalDue);

      final success = await printerService.printInvoiceReceipt(
        invoiceId: invoice.id,
        customerName: invoice.customerName,
        idpl: invoice.customerIdpl,
        period: invoice.invoicePeriod,
        totalAmount: invoice.totalDue,
        paidAmount: actualPaid,
        status: actualStatus,
        paymentMethod: customMethod ?? invoice.paymentMethod,
        paidDate: invoice.paidAt ?? DateTime.now(),
        ispName: tenantName,
        ispPhone: tenantPhone,
        ispAddress: tenantAddress,
        receiptFooter: receiptFooter,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk.'),
            backgroundColor: success ? const Color(0xFF22C55E) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cetak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
