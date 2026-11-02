import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import 'auth_provider.dart';

// Repository Provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ExpenseRepository(supabase);
});

// Search Query Provider
final expenseSearchQueryProvider = StateProvider<String>((ref) => '');

// Date Filter Providers
final expenseStartDateProvider = StateProvider<DateTime?>((ref) => null);
final expenseEndDateProvider = StateProvider<DateTime?>((ref) => null);

// Expenses List Provider
final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final repository = ref.watch(expenseRepositoryProvider);
  final searchQuery = ref.watch(expenseSearchQueryProvider);
  final startDate = ref.watch(expenseStartDateProvider);
  final endDate = ref.watch(expenseEndDateProvider);

  return repository.getExpenses(
    startDate: startDate,
    endDate: endDate,
    searchQuery: searchQuery.isEmpty ? null : searchQuery,
  );
});

// Total Expenses Provider
final totalExpensesProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(expenseRepositoryProvider);
  final startDate = ref.watch(expenseStartDateProvider);
  final endDate = ref.watch(expenseEndDateProvider);

  return repository.getTotalExpenses(
    startDate: startDate,
    endDate: endDate,
  );
});

// Expense Controller
class ExpenseController extends StateNotifier<AsyncValue<void>> {
  final ExpenseRepository _repository;

  ExpenseController(this._repository) : super(const AsyncValue.data(null));

  Future<void> createExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createExpense(expense);
    });
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateExpense(expense);
    });
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteExpense(id);
    });
  }
}

final expenseControllerProvider =
    StateNotifierProvider<ExpenseController, AsyncValue<void>>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseController(repository);
});
