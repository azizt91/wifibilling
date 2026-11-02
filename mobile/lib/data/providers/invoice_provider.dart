import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/invoice_repository.dart';
import '../models/invoice_model.dart';
import 'supabase_provider.dart';
import 'cache_provider.dart';

// Invoice Repository Provider
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(
    ref.read(supabaseClientProvider),
    ref.read(cacheServiceProvider),
    ref.read(connectivityServiceProvider),
  );
});

// Filter State Providers
final invoiceSearchQueryProvider = StateProvider<String>((ref) => '');
final invoiceStartDateProvider = StateProvider<DateTime?>((ref) => null);
final invoiceEndDateProvider = StateProvider<DateTime?>((ref) => null);
final invoicePageProvider = StateProvider.family<int, String>((ref, status) => 1);

// Current Tab Provider
final invoiceTabProvider = StateProvider<int>((ref) => 0);

// Invoices List Provider by Status
final invoicesProvider = FutureProvider.autoDispose.family<List<InvoiceModel>, String>(
  (ref, status) async {
    final repository = ref.watch(invoiceRepositoryProvider);
    final searchQuery = ref.watch(invoiceSearchQueryProvider);
    final startDate = ref.watch(invoiceStartDateProvider);
    final endDate = ref.watch(invoiceEndDateProvider);
    final page = ref.watch(invoicePageProvider(status));

    return repository.getInvoices(
      status: status,
      page: page,
      limit: 20,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
  },
);

// Invoice Count Provider
final invoiceCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, status) async {
    final repository = ref.watch(invoiceRepositoryProvider);
    final searchQuery = ref.watch(invoiceSearchQueryProvider);
    final startDate = ref.watch(invoiceStartDateProvider);
    final endDate = ref.watch(invoiceEndDateProvider);

    return repository.getInvoiceCount(
      status: status,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
  },
);

// Single Invoice Provider
final invoiceByIdProvider = FutureProvider.autoDispose.family<InvoiceModel, String>(
  (ref, id) async {
    final repository = ref.watch(invoiceRepositoryProvider);
    return repository.getInvoiceById(id);
  },
);

// Invoice Stats Provider
final invoiceStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.getInvoiceStats();
});

// Customer Invoices Provider
final customerInvoicesProvider = FutureProvider.autoDispose.family<List<InvoiceModel>, String>(
  (ref, customerId) async {
    final repository = ref.watch(invoiceRepositoryProvider);
    return repository.getCustomerInvoices(customerId);
  },
);

// Invoice Controller (for CRUD operations)
class InvoiceController extends StateNotifier<AsyncValue<void>> {
  final InvoiceRepository _repository;

  InvoiceController(this._repository) : super(const AsyncValue.data(null));

  Future<InvoiceModel> createInvoice({
    required String customerId,
    required double amount,
    required DateTime dueDate,
    String? description,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final invoice = await _repository.createInvoice(
        customerId: customerId,
        amount: amount,
        dueDate: dueDate,
        description: description,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return invoice;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<InvoiceModel> processPayment({
    required String invoiceId,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final invoice = await _repository.processPayment(
        invoiceId: invoiceId,
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return invoice;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<InvoiceModel> updateInvoice({
    required String id,
    double? amount,
    DateTime? dueDate,
    String? description,
    String? notes,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    try {
      final invoice = await _repository.updateInvoice(
        id: id,
        amount: amount,
        dueDate: dueDate,
        description: description,
        notes: notes,
        status: status,
      );
      state = const AsyncValue.data(null);
      return invoice;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteInvoice(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteInvoice(id);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createMonthlyInvoices() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.createMonthlyInvoices();
      state = const AsyncValue.data(null);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<InvoiceModel> getInvoiceById(String id) async {
    try {
      return await _repository.getInvoiceById(id);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> processInstallmentPayment({
    required String invoiceId,
    required double paymentAmount,
    required String adminName,
    String paymentMethod = 'cash',
    String note = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.processInstallmentPayment(
        invoiceId: invoiceId,
        paymentAmount: paymentAmount,
        adminName: adminName,
        paymentMethod: paymentMethod,
        note: note,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<InvoiceModel> markAsPaid({
    required String invoiceId,
    required String paymentMethod,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final invoice = await _repository.markAsPaid(
        invoiceId: invoiceId,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return invoice;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final invoiceControllerProvider =
    StateNotifierProvider<InvoiceController, AsyncValue<void>>((ref) {
  return InvoiceController(ref.read(invoiceRepositoryProvider));
});

// Alias for backward compatibility
final invoicesByStatusProvider = invoicesProvider;
