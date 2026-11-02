import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
import 'auth_provider.dart';

// Dashboard Repository Provider
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(supabaseClientProvider));
});

// Filter State Providers
final selectedMonthProvider = StateProvider<int>((ref) => DateTime.now().month);
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  final month = ref.watch(selectedMonthProvider);
  final year = ref.watch(selectedYearProvider);

  return repository.getDashboardStats(month: month, year: year);
});

// Monthly Revenue Provider (for chart)
final monthlyRevenueProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getMonthlyRevenue(months: 6);
});

// Recent Invoices Provider
final recentInvoicesProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getRecentInvoices(limit: 5);
});

// Recent Customers Provider
final recentCustomersProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getRecentCustomers(limit: 5);
});

// Dashboard Charts Data Provider
final dashboardChartsDataProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardChartsData(months: 6);
});

// Alias for dashboard charts (used in admin dashboard)
final dashboardChartsProvider = dashboardChartsDataProvider;

// All Customers Provider with filter and search
final customersFilterProvider = StateProvider<String>((ref) => 'all');
final customersSearchProvider = StateProvider<String>((ref) => '');

final allCustomersProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  final filter = ref.watch(customersFilterProvider);
  final search = ref.watch(customersSearchProvider);
  
  return repository.getAllCustomers(filter: filter, searchTerm: search);
});

// Customer Detail Provider
final customerDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, customerId) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  
  final customer = await repository.getCustomerById(customerId);
  final invoices = await repository.getCustomerInvoices(customerId);
  
  // Convert invoices to list of maps
  final invoicesList = invoices.map((inv) => inv.toJson()).toList();
  
  return {
    'customer': customer,
    'invoices': invoicesList,
  };
});
