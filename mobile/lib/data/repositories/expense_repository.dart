import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final SupabaseClient _supabase;

  ExpenseRepository(this._supabase);

  Future<List<ExpenseModel>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    // Get all expenses first, then filter locally
    final response = await _supabase
        .from('expenses')
        .select()
        .order('expense_date', ascending: false);
    
    final data = response as List;
    var expenses = data.map((json) => ExpenseModel.fromJson(json)).toList();

    // Apply date filters locally
    if (startDate != null) {
      expenses = expenses.where((expense) {
        return expense.expenseDate.isAfter(startDate.subtract(const Duration(days: 1)));
      }).toList();
    }

    if (endDate != null) {
      expenses = expenses.where((expense) {
        return expense.expenseDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply search filter locally
    if (searchQuery != null && searchQuery.isNotEmpty) {
      expenses = expenses.where((expense) {
        return expense.description.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    return expenses;
  }

  Future<double> getTotalExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final expenses = await getExpenses(
      startDate: startDate,
      endDate: endDate,
    );
    
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<ExpenseModel> createExpense(ExpenseModel expense) async {
    final response = await _supabase
        .from('expenses')
        .insert(expense.toJson())
        .select()
        .single();

    return ExpenseModel.fromJson(response);
  }

  Future<ExpenseModel> updateExpense(ExpenseModel expense) async {
    final response = await _supabase
        .from('expenses')
        .update(expense.toJson())
        .eq('id', expense.id!)
        .select()
        .single();

    return ExpenseModel.fromJson(response);
  }

  Future<void> deleteExpense(String id) async {
    await _supabase.from('expenses').delete().eq('id', id);
  }
}
