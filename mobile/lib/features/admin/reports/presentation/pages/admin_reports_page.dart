import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:csv/csv.dart';
import '../../../../../core/utils/csv_file_helper.dart';
import '../../../../../core/services/report_pdf_service.dart';
import '../../../../../data/providers/auth_provider.dart';

// Report Data Model
class ReportData {
  final List<ReportItem> items;
  final double totalPendapatan;
  final double totalLunas;
  final double totalUnpaid;
  final double totalInstallment;
  final double totalPengeluaran;
  final int countLunas;
  final int countUnpaid;
  final int countInstallment;
  final int countPengeluaran;

  ReportData({
    required this.items,
    required this.totalPendapatan,
    required this.totalLunas,
    required this.totalUnpaid,
    required this.totalInstallment,
    required this.totalPengeluaran,
    required this.countLunas,
    required this.countUnpaid,
    required this.countInstallment,
    required this.countPengeluaran,
  });
}

class ReportItem {
  final String type;
  final DateTime date;
  final String customerName;
  final String customerId;
  final String description;
  final double amount;
  final String status;
  final String paymentMethod;

  ReportItem({
    required this.type,
    required this.date,
    required this.customerName,
    required this.customerId,
    required this.description,
    required this.amount,
    required this.status,
    required this.paymentMethod,
  });
}

// Filter State
class ReportFilter {
  final String periode;
  final String status;
  final String paymentMethod;
  final String customerSearch;
  final DateTime? startDate;
  final DateTime? endDate;

  ReportFilter({
    this.periode = 'all',
    this.status = 'all',
    this.paymentMethod = 'all',
    this.customerSearch = '',
    this.startDate,
    this.endDate,
  });
}

final reportFilterProvider = StateProvider<ReportFilter>((ref) => ReportFilter());

final reportDataProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final filter = ref.watch(reportFilterProvider);

  // Fetch invoices
  final invoicesResponse = await supabase
      .from('invoices')
      .select('*, profiles:customer_id(full_name, idpl)')
      .order('created_at', ascending: false);

  // Fetch expenses
  final expensesResponse = await supabase
      .from('expenses')
      .select('*')
      .order('expense_date', ascending: false);

  final invoices = invoicesResponse as List;
  final expenses = expensesResponse as List;

  // Filter by date / periode
  List<dynamic> filteredInvoices = invoices;
  List<dynamic> filteredExpenses = expenses;

  if (filter.periode != 'all' || filter.startDate != null) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (filter.periode) {
      case 'bulan-ini':
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        break;
      case 'bulan-lalu':
        start = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
        end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
        break;
      case '3-bulan':
        start = DateTime(now.year, now.month - 3, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case '6-bulan':
        start = DateTime(now.year, now.month - 6, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'tahun-ini':
        start = DateTime(now.year, 1, 1, 0, 0, 0);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case 'custom':
        if (filter.startDate != null) {
          start = DateTime(
              filter.startDate!.year, filter.startDate!.month, filter.startDate!.day, 0, 0, 0);
        }
        if (filter.endDate != null) {
          end = DateTime(
              filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59, 999);
        }
        break;
    }

    bool isInRange(DateTime date) {
      if (start != null && date.isBefore(start)) return false;
      if (end != null && date.isAfter(end)) return false;
      return true;
    }

    filteredInvoices = invoices.where((inv) {
      final dateStr =
          inv['paid_at']?.toString() ?? inv['created_at']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;
      return isInRange(date);
    }).toList();

    filteredExpenses = expenses.where((exp) {
      final date = DateTime.tryParse(exp['expense_date']?.toString() ?? '');
      if (date == null) return false;
      return isInRange(date);
    }).toList();
  }

  // 2. Filter by status
  if (filter.status != 'all') {
    final s = filter.status.toLowerCase();
    if (s == 'expense') {
      filteredInvoices = [];
    } else {
      filteredExpenses = [];
      filteredInvoices = filteredInvoices.where((inv) {
        final invStatus = inv['status']?.toString().toLowerCase() ?? '';
        if (s == 'partially_paid' || s == 'installment') {
          return invStatus == 'partially_paid' || invStatus == 'installment';
        }
        return invStatus == s;
      }).toList();
    }
  }

  // 3. Filter by payment method
  if (filter.paymentMethod != 'all') {
    filteredExpenses = [];
    final targetMethod = filter.paymentMethod.toLowerCase();
    filteredInvoices = filteredInvoices.where((inv) {
      final status = inv['status']?.toString().toLowerCase() ?? '';
      if (status == 'paid' || status == 'partially_paid' || status == 'installment') {
        final method = inv['payment_method']?.toString().toLowerCase() ?? '';
        return method.contains(targetMethod);
      }
      return false;
    }).toList();
  }

  // 4. Filter by customer search
  if (filter.customerSearch.isNotEmpty) {
    filteredExpenses = [];
    final search = filter.customerSearch.toLowerCase();
    filteredInvoices = filteredInvoices.where((inv) {
      final profile = inv['profiles'] as Map<String, dynamic>?;
      final name = profile?['full_name']?.toString().toLowerCase() ?? '';
      final idpl = profile?['idpl']?.toString().toLowerCase() ?? '';
      return name.contains(search) || idpl.contains(search);
    }).toList();
  }

  // 5. Build report items
  final items = <ReportItem>[];

  for (final inv in filteredInvoices) {
    final profile = inv['profiles'] as Map<String, dynamic>?;
    final status = inv['status']?.toString().toLowerCase() ?? 'unpaid';

    double itemAmount;
    if (status == 'paid') {
      itemAmount = (inv['total_due'] as num?)?.toDouble() ??
          (inv['amount'] as num?)?.toDouble() ??
          0.0;
    } else if (status == 'partially_paid' || status == 'installment') {
      itemAmount = (inv['amount_paid'] as num?)?.toDouble() ?? 0.0;
    } else {
      itemAmount = (inv['amount'] as num?)?.toDouble() ??
          (inv['total_due'] as num?)?.toDouble() ??
          0.0;
    }

    items.add(ReportItem(
      type: 'income',
      date: DateTime.tryParse(
              inv['paid_at']?.toString() ?? inv['created_at']?.toString() ?? '') ??
          DateTime.now(),
      customerName: profile?['full_name']?.toString() ?? 'N/A',
      customerId: profile?['idpl']?.toString() ?? 'N/A',
      description: inv['invoice_period']?.toString() ?? '-',
      amount: itemAmount,
      status: status,
      paymentMethod: inv['payment_method']?.toString() ?? '-',
    ));
  }

  for (final exp in filteredExpenses) {
    items.add(ReportItem(
      type: 'expense',
      date: DateTime.tryParse(exp['expense_date']?.toString() ?? '') ?? DateTime.now(),
      customerName: '-',
      customerId: '-',
      description: exp['description']?.toString() ?? '-',
      amount: (exp['amount'] as num?)?.toDouble() ?? 0.0,
      status: 'expense',
      paymentMethod: '-',
    ));
  }

  // Sort by date descending
  items.sort((a, b) => b.date.compareTo(a.date));

  // 6. Calculate totals
  final paid = filteredInvoices
      .where((inv) => inv['status']?.toString().toLowerCase() == 'paid')
      .toList();
  final unpaid = filteredInvoices
      .where((inv) => inv['status']?.toString().toLowerCase() == 'unpaid')
      .toList();
  final installment = filteredInvoices.where((inv) {
    final s = inv['status']?.toString().toLowerCase() ?? '';
    return s == 'partially_paid' || s == 'installment';
  }).toList();

  final totalLunas = paid.fold<double>(
      0.0,
      (sum, inv) =>
          sum +
          ((inv['total_due'] as num?)?.toDouble() ??
              (inv['amount'] as num?)?.toDouble() ??
              0.0));
  final totalInstallment = installment.fold<double>(
      0.0, (sum, inv) => sum + ((inv['amount_paid'] as num?)?.toDouble() ?? 0.0));
  final totalPendapatan = totalLunas + totalInstallment;
  final totalUnpaid = unpaid.fold<double>(
      0.0,
      (sum, inv) =>
          sum +
          ((inv['amount'] as num?)?.toDouble() ??
              (inv['total_due'] as num?)?.toDouble() ??
              0.0));
  final totalPengeluaran = filteredExpenses.fold<double>(
      0.0, (sum, exp) => sum + ((exp['amount'] as num?)?.toDouble() ?? 0.0));

  return ReportData(
    items: items,
    totalPendapatan: totalPendapatan,
    totalLunas: totalLunas,
    totalUnpaid: totalUnpaid,
    totalInstallment: totalInstallment,
    totalPengeluaran: totalPengeluaran,
    countLunas: paid.length,
    countUnpaid: unpaid.length,
    countInstallment: installment.length,
    countPengeluaran: filteredExpenses.length,
  );
});

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});
  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final reportData = ref.watch(reportDataProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: reportData.when(
                data: (data) => _buildContent(data),
                loading: () => _buildLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final filter = ref.watch(reportFilterProvider);
    final hasActiveFilter = filter.periode != 'all' ||
        filter.status != 'all' ||
        filter.paymentMethod != 'all' ||
        filter.customerSearch.isNotEmpty ||
        filter.startDate != null ||
        filter.endDate != null;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF110E1B))),
              const Expanded(
                  child: Text('Laporan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF110E1B)))),
              Stack(
                children: [
                  GestureDetector(
                      onTap: _showFilterModal,
                      child: const Icon(Icons.filter_list, color: Color(0xFF110E1B))),
                  if (hasActiveFilter)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFF683FE4), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ReportData data) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reportDataProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCards(data),
          const SizedBox(height: 16),
          _buildExportButtons(data),
          const SizedBox(height: 16),
          _buildDataTable(data),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ReportData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildSummaryCard(
                    'Total Pendapatan',
                    _currencyFormat.format(data.totalPendapatan),
                    '${data.countLunas + data.countInstallment} Transaksi',
                    const Color(0xFF22C55E),
                    Icons.payments_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSummaryCard(
                    'Lunas',
                    _currencyFormat.format(data.totalLunas),
                    '${data.countLunas} Tagihan',
                    const Color(0xFF3B82F6),
                    Icons.check_circle_outline)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildSummaryCard(
                    'Belum Bayar',
                    _currencyFormat.format(data.totalUnpaid),
                    '${data.countUnpaid} Tagihan',
                    const Color(0xFFEF4444),
                    Icons.error_outline)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSummaryCard(
                    'Cicilan',
                    _currencyFormat.format(data.totalInstallment),
                    '${data.countInstallment} Tagihan',
                    const Color(0xFFF97316),
                    Icons.schedule)),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
            'Pengeluaran',
            _currencyFormat.format(data.totalPengeluaran),
            '${data.countPengeluaran} Pengeluaran',
            const Color(0xFF8B5CF6),
            Icons.account_balance_wallet_outlined,
            fullWidth: true),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, String subtitle, Color color, IconData icon,
      {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildExportButtons(ReportData data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportToPDF(data),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf, size: 20),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportToExcel(data),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_chart, size: 20),
            label: const Text('Export Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(ReportData data) {
    if (data.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Tidak ada data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            const Text('Coba ubah filter untuk melihat data lainnya',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    final incomeCount = data.items.where((i) => i.type == 'income').length;
    final expenseCount = data.items.where((i) => i.type == 'expense').length;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Tagihan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    'Menampilkan ${data.items.length} data ($incomeCount pendapatan, $expenseCount pengeluaran)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.grey[50],
            child: Row(
              children: [
                const SizedBox(
                    width: 30,
                    child: Text('No',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151)))),
                const Expanded(
                    flex: 2,
                    child: Text('Nama',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151)))),
                const Expanded(
                    child: Text('Jumlah',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151)),
                        textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                SizedBox(
                    width: 70,
                    child: Text('Status',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...data.items.take(100).toList().asMap().entries.map((entry) =>
              _buildDataRow(entry.value, entry.key + 1)),
          if (data.items.length > 100)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('... dan ${data.items.length - 100} data lainnya',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(ReportItem item, int index) {
    final dateFormat = DateFormat('dd/MM/yy', 'id_ID');
    final isExpense = item.type == 'expense';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(
        children: [
          SizedBox(
              width: 30,
              child: Text('$index',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.customerName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item.description,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text(dateFormat.format(item.date),
                    style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${isExpense ? '-' : '+'}${_currencyFormat.format(item.amount)}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isExpense ? const Color(0xFF8B5CF6) : const Color(0xFF22C55E)),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: _buildStatusBadge(item.status)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'paid':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        label = 'Lunas';
        break;
      case 'unpaid':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'Belum';
        break;
      case 'partially_paid':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Cicilan';
        break;
      case 'expense':
        bgColor = const Color(0xFFEDE9FE);
        textColor = const Color(0xFF7C3AED);
        label = 'Keluar';
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
                child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12))))
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12))))
          ]),
          const SizedBox(height: 12),
          Container(
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8)))),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8))))
          ]),
          const SizedBox(height: 16),
          Container(
              height: 300,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12))),
        ],
      ),
    );
  }


  Future<void> _showFilterModal() async {
    final filter = ref.read(reportFilterProvider);
    String selectedPeriode = filter.periode;
    String selectedStatus = filter.status;
    String selectedPaymentMethod = filter.paymentMethod;
    final searchController = TextEditingController(text: filter.customerSearch);
    DateTime? startDate = filter.startDate;
    DateTime? endDate = filter.endDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter Laporan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    GestureDetector(
                        onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 24),

                // Periode
                const Text('Periode', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPeriode,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Periode')),
                    DropdownMenuItem(value: 'bulan-ini', child: Text('Bulan Ini')),
                    DropdownMenuItem(value: 'bulan-lalu', child: Text('Bulan Lalu')),
                    DropdownMenuItem(value: '3-bulan', child: Text('3 Bulan Terakhir')),
                    DropdownMenuItem(value: '6-bulan', child: Text('6 Bulan Terakhir')),
                    DropdownMenuItem(value: 'tahun-ini', child: Text('Tahun Ini')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                  ],
                  onChanged: (v) => setModalState(() {
                    selectedPeriode = v ?? 'all';
                    if (selectedPeriode != 'custom') {
                      startDate = null;
                      endDate = null;
                    }
                  }),
                ),

                // Custom Date Range
                if (selectedPeriode == 'custom') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal Mulai',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setModalState(() => startDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    startDate != null
                                        ? DateFormat('dd/MM/yyyy').format(startDate!)
                                        : 'Pilih tanggal',
                                    style: TextStyle(
                                        color: startDate != null
                                            ? Colors.black
                                            : Colors.grey[500])),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal Akhir',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setModalState(() => endDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    endDate != null
                                        ? DateFormat('dd/MM/yyyy').format(endDate!)
                                        : 'Pilih tanggal',
                                    style: TextStyle(
                                        color:
                                            endDate != null ? Colors.black : Colors.grey[500])),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Status
                const Text('Status Pembayaran', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                    DropdownMenuItem(value: 'partially_paid', child: Text('Cicilan')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Belum Bayar')),
                    DropdownMenuItem(value: 'expense', child: Text('Pengeluaran')),
                  ],
                  onChanged: (v) => setModalState(() => selectedStatus = v ?? 'all'),
                ),

                const SizedBox(height: 16),

                // Payment Method
                const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Metode')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer Bank')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                    DropdownMenuItem(value: 'e-wallet', child: Text('E-Wallet')),
                  ],
                  onChanged: (v) => setModalState(() => selectedPaymentMethod = v ?? 'all'),
                ),

                const SizedBox(height: 16),

                // Customer Search
                const Text('Cari Pelanggan', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Nama atau ID Pelanggan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(reportFilterProvider.notifier).state = ReportFilter();
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(reportFilterProvider.notifier).state = ReportFilter(
                            periode: selectedPeriode,
                            status: selectedStatus,
                            paymentMethod: selectedPaymentMethod,
                            customerSearch: searchController.text.trim(),
                            startDate: startDate,
                            endDate: endDate,
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF683FE4),
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _getTenantName() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // 1. Coba ambil dari app_settings (nama aplikasi/toko yang diatur admin tenant)
      final settings = await supabase
          .from('app_settings')
          .select('app_name')
          .limit(1)
          .maybeSingle();
      if (settings != null && settings['app_name'] != null) {
        final appName = settings['app_name'].toString().trim();
        if (appName.isNotEmpty && appName != 'WiFi Billing System') {
          return appName;
        }
      }

      // 2. Coba ambil nama bisnis/perusahaan dari tabel tenants
      final tenant = await supabase
          .from('tenants')
          .select('name')
          .limit(1)
          .maybeSingle();
      if (tenant != null && tenant['name'] != null) {
        final name = tenant['name'].toString().trim();
        if (name.isNotEmpty) {
          return name;
        }
      }

      // 3. Fallback jika ada app_name default
      if (settings != null && settings['app_name'] != null) {
        final appName = settings['app_name'].toString().trim();
        if (appName.isNotEmpty) return appName;
      }
    } catch (e) {
      debugPrint('Error getting tenant name for report: $e');
    }

    return 'WiFi Billing System';
  }

  Future<void> _exportToPDF(ReportData data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final tenantName = await _getTenantName();
      final safeTenant = tenantName.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      final fileName = 'laporan_keuangan_${safeTenant}_$dateStr.pdf';

      // 1. Generate PDF bytes
      final pdfBytes = await ReportPdfService.generatePdf(
        data: data,
        storeName: tenantName,
        currencyFormat: _currencyFormat,
      );

      // 2. Save PDF file
      final savedPath = await CsvFileHelper.savePdf(
        fileName: fileName,
        bytes: pdfBytes,
      );

      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        if (savedPath != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✅ File PDF berhasil disimpan:\n$fileName'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'BUKA',
                textColor: Colors.white,
                onPressed: () => CsvFileHelper.openFile(savedPath),
              ),
            ),
          );
          // Auto open file
          await CsvFileHelper.openFile(savedPath);
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan file PDF ke penyimpanan lokal.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('❌ Gagal export PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel(ReportData data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(DateTime.now());
      final tenantName = await _getTenantName();
      final safeTenant = tenantName.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      final fileName = 'laporan_keuangan_${safeTenant}_$dateStr.csv';
      final netIncome = data.totalPendapatan - data.totalPengeluaran;

      final headers = [
        'No',
        'Tanggal',
        'Tipe',
        'Nama Pelanggan / Penerima',
        'ID Pelanggan',
        'Keterangan',
        'Nominal (Rp)',
        'Status',
        'Metode Pembayaran',
      ];

      final rows = List<List<dynamic>>.generate(data.items.length, (index) {
        final item = data.items[index];
        final isExpense = item.type == 'expense';
        return [
          index + 1,
          dateFormat.format(item.date),
          isExpense ? 'Pengeluaran' : 'Pendapatan',
          item.customerName,
          item.customerId,
          item.description,
          isExpense ? -item.amount : item.amount,
          _getStatusText(item.status),
          item.paymentMethod.isNotEmpty ? item.paymentMethod : '-',
        ];
      });

      // Add summary rows at the bottom
      final summaryRows = [
        [],
        ['--- RINGKASAN LAPORAN KEUANGAN ($tenantName) ---'],
        ['Tenant / ISP', tenantName],
        ['Total Pendapatan (Lunas)', data.totalPendapatan],
        ['Total Pengeluaran', data.totalPengeluaran],
        ['Pendapatan Bersih', netIncome],
        ['Total Belum Bayar', data.totalUnpaid],
        ['Total Cicilan', data.totalInstallment],
        ['Jumlah Transaksi', data.items.length],
        ['Tanggal Cetak', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())],
      ];

      final csvContent = const ListToCsvConverter().convert([
        headers,
        ...rows,
        ...summaryRows,
      ]);

      final savedPath = await CsvFileHelper.saveCsv(
        fileName: fileName,
        content: csvContent,
      );

      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        if (savedPath != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✅ File Excel/CSV berhasil disimpan:\n$fileName'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'BUKA',
                textColor: Colors.white,
                onPressed: () => CsvFileHelper.openFile(savedPath),
              ),
            ),
          );
          // Auto open file
          await CsvFileHelper.openFile(savedPath);
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Data berhasil disalin ke clipboard!'),
              backgroundColor: Color(0xFF3B82F6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('❌ Gagal export Excel: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Lunas';
      case 'unpaid':
        return 'Belum Bayar';
      case 'partially_paid':
        return 'Cicilan';
      case 'expense':
        return 'Pengeluaran';
      default:
        return status;
    }
  }
}
