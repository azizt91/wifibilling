import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../data/providers/auth_provider.dart';

// Expense Model
class ExpenseModel {
  final String id; // UUID dari database
  final String description;
  final double amount;
  final DateTime expenseDate;
  final DateTime? createdAt;

  ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.expenseDate,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      expenseDate: json['expense_date'] != null 
          ? DateTime.parse(json['expense_date'].toString())
          : DateTime.now(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

// Filter State
class ExpenseFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String search;

  ExpenseFilter({this.startDate, this.endDate, this.search = ''});

  ExpenseFilter copyWith({DateTime? startDate, DateTime? endDate, String? search, bool clearDates = false}) {
    return ExpenseFilter(
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      search: search ?? this.search,
    );
  }
}

// Providers
final expenseFilterProvider = StateProvider<ExpenseFilter>((ref) => ExpenseFilter());

final expensesProvider = FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final filter = ref.watch(expenseFilterProvider);

  var query = supabase.from('expenses').select('*');

  if (filter.startDate != null) {
    query = query.gte('expense_date', DateFormat('yyyy-MM-dd').format(filter.startDate!));
  }
  if (filter.endDate != null) {
    query = query.lte('expense_date', DateFormat('yyyy-MM-dd').format(filter.endDate!));
  }

  final response = await query.order('expense_date', ascending: false);
  
  var expenses = (response as List).map((e) => ExpenseModel.fromJson(e)).toList();

  // Apply search filter locally
  if (filter.search.isNotEmpty) {
    expenses = expenses.where((exp) =>
      exp.description.toLowerCase().contains(filter.search.toLowerCase()) ||
      exp.amount.toString().contains(filter.search)
    ).toList();
  }

  return expenses;
});

class AdminExpensesPage extends ConsumerStatefulWidget {
  const AdminExpensesPage({super.key});
  @override
  ConsumerState<AdminExpensesPage> createState() => _AdminExpensesPageState();
}

class _AdminExpensesPageState extends ConsumerState<AdminExpensesPage> {
  final _searchController = TextEditingController();
  bool _showTotalContainer = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final currentFilter = ref.read(expenseFilterProvider);
    ref.read(expenseFilterProvider.notifier).state = currentFilter.copyWith(search: value);
  }

  void _clearSearch() {
    _searchController.clear();
    final currentFilter = ref.read(expenseFilterProvider);
    ref.read(expenseFilterProvider.notifier).state = currentFilter.copyWith(search: '');
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final filter = ref.watch(expenseFilterProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(filter),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(expensesProvider),
                child: expenses.when(
                  data: (data) => _buildExpenseList(data),
                  loading: () => _buildSkeletonList(),
                  error: (e, _) => _buildError(e.toString()),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddExpenseModal(),
          backgroundColor: const Color(0xFF683FE4),
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(ExpenseFilter filter) {
    return Container(
      color: const Color(0xFFF9F8FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title with filter button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const Expanded(
                    child: Text(
                      'Pengeluaran',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.filter_list,
                        color: (filter.startDate != null || filter.endDate != null) 
                            ? const Color(0xFF683FE4) 
                            : const Color(0xFF110E1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Cari pengeluaran...',
                          hintStyle: TextStyle(color: Color(0xFF625095), fontSize: 16),
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
            // Total Expense Container (shown when filter is active)
            if (_showTotalContainer || filter.startDate != null || filter.endDate != null)
              _buildTotalExpenseContainer(filter),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalExpenseContainer(ExpenseFilter filter) {
    final expenses = ref.watch(expensesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    double total = 0;
    expenses.whenData((data) {
      total = data.fold(0, (sum, item) => sum + item.amount);
    });

    String filterInfo = '';
    if (filter.startDate != null || filter.endDate != null) {
      final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
      final start = filter.startDate != null ? dateFormat.format(filter.startDate!) : '...';
      final end = filter.endDate != null ? dateFormat.format(filter.endDate!) : '...';
      filterInfo = 'Filter aktif: $start - $end';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Pengeluaran', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(total),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
          ),
          if (filterInfo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(filterInfo, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseList(List<ExpenseModel> data) {
    if (data.isEmpty) {
      final searchTerm = _searchController.text.trim();
      String message = 'Tidak ada data pengeluaran';
      String submessage = 'Tambahkan pengeluaran baru dengan tombol + di bawah';

      if (searchTerm.isNotEmpty) {
        message = 'Tidak ada pengeluaran ditemukan';
        submessage = 'Coba ubah filter atau kata kunci pencarian';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 96, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Text(submessage, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: data.length,
      itemBuilder: (_, i) => _buildExpenseItem(data[i]),
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF110E1B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(expense.expenseDate),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(expense.amount),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 8),
          // Edit button
          GestureDetector(
            onTap: () => _showEditExpenseModal(expense),
            child: Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 18),
            ),
          ),
          // Delete button
          GestureDetector(
            onTap: () => _confirmDeleteExpense(expense),
            child: Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
            ),
          ),
        ],
      ),
    );
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
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 180, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 4),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
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
              onPressed: () => ref.invalidate(expensesProvider),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4), foregroundColor: Colors.white),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // Filter Modal
  Future<void> _showFilterModal() async {
    final filter = ref.read(expenseFilterProvider);
    DateTime? startDate = filter.startDate;
    DateTime? endDate = filter.endDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close, size: 24),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dari Tanggal', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => startDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    startDate != null ? DateFormat('dd MMM yyyy', 'id_ID').format(startDate!) : 'Pilih tanggal',
                    style: TextStyle(color: startDate != null ? Colors.black : Colors.grey[500]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sampai Tanggal', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => endDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    endDate != null ? DateFormat('dd MMM yyyy', 'id_ID').format(endDate!) : 'Pilih tanggal',
                    style: TextStyle(color: endDate != null ? Colors.black : Colors.grey[500]),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(expenseFilterProvider.notifier).state = ExpenseFilter(search: filter.search);
                setState(() => _showTotalContainer = false);
                Navigator.pop(ctx);
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                if (startDate != null && endDate != null && startDate!.isAfter(endDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tanggal awal tidak boleh melebihi tanggal akhir')),
                  );
                  return;
                }
                ref.read(expenseFilterProvider.notifier).state = ExpenseFilter(
                  startDate: startDate,
                  endDate: endDate,
                  search: filter.search,
                );
                setState(() => _showTotalContainer = true);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4)),
              child: const Text('Terapkan Filter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Add Expense Modal
  Future<void> _showAddExpenseModal() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.arrow_back, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Tambah Pengeluaran', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 36),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deskripsi Pengeluaran', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan deskripsi pengeluaran',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan jumlah pengeluaran',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (descController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mohon isi deskripsi pengeluaran')),
                    );
                    return;
                  }
                  final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mohon isi jumlah yang valid')),
                    );
                    return;
                  }

                  await _saveExpense(descController.text.trim(), amount, selectedDate);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5324E0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(expensesProvider);
    }
  }


  // Edit Expense Modal
  Future<void> _showEditExpenseModal(ExpenseModel expense) async {
    final descController = TextEditingController(text: expense.description);
    final amountController = TextEditingController(text: expense.amount.toInt().toString());
    DateTime selectedDate = expense.expenseDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.arrow_back, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Edit Pengeluaran', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 36),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deskripsi Pengeluaran', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan deskripsi pengeluaran',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan jumlah pengeluaran',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (descController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mohon isi deskripsi pengeluaran')),
                    );
                    return;
                  }
                  final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mohon isi jumlah yang valid')),
                    );
                    return;
                  }

                  await _updateExpense(expense.id.toString(), descController.text.trim(), amount, selectedDate);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5324E0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(expensesProvider);
    }
  }

  // Confirm Delete
  Future<void> _confirmDeleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: Text('Apakah Anda yakin ingin menghapus pengeluaran "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteExpense(expense.id.toString());
    }
  }

  // Save new expense
  Future<void> _saveExpense(String description, double amount, DateTime date) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      await supabase.from('expenses').insert({
        'description': description,
        'amount': amount,
        'expense_date': DateFormat('yyyy-MM-dd').format(date),
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran berhasil ditambahkan'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengeluaran: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // Update expense
  Future<void> _updateExpense(String id, String description, double amount, DateTime date) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      await supabase.from('expenses').update({
        'description': description,
        'amount': amount,
        'expense_date': DateFormat('yyyy-MM-dd').format(date),
      }).eq('id', id);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran berhasil diupdate'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mengupdate pengeluaran: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // Delete expense
  Future<void> _deleteExpense(String id) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      await supabase.from('expenses').delete().eq('id', id);

      ref.invalidate(expensesProvider);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran berhasil dihapus'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus pengeluaran: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }
}
