import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_model.dart';
import '../models/profile_model.dart';

class DashboardStats {
  final double totalRevenue;
  final double totalExpenses;
  final double profit;
  final int activeCustomers;
  final int inactiveCustomers;
  final int unpaidInvoicesCount;
  final int paidInvoicesCount;

  DashboardStats({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.profit,
    required this.activeCustomers,
    required this.inactiveCustomers,
    required this.unpaidInvoicesCount,
    required this.paidInvoicesCount,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      activeCustomers: json['active_customers'] as int? ?? 0,
      inactiveCustomers: json['inactive_customers'] as int? ?? 0,
      unpaidInvoicesCount: json['unpaid_invoices_count'] as int? ?? 0,
      paidInvoicesCount: json['paid_invoices_count'] as int? ?? 0,
    );
  }

  // Computed properties for compatibility
  int get totalCustomers => activeCustomers + inactiveCustomers;
  int get unpaidInvoices => unpaidInvoicesCount;
  int get paidInvoices => paidInvoicesCount;
  int get installmentInvoices => 0; // Not provided by RPC
}

class DashboardChartsData {
  final List<double> revenueData;
  final List<double> expensesData;
  final List<double> profitData;
  final List<int> customerGrowthData;
  final List<int> customerTotalData;
  final List<int> customerNetData;
  final List<String> labels;
  final Map<String, int> invoiceStatusCounts;

  DashboardChartsData({
    required this.revenueData,
    required this.expensesData,
    required this.profitData,
    required this.customerGrowthData,
    required this.customerTotalData,
    required this.customerNetData,
    required this.labels,
    required this.invoiceStatusCounts,
  });

  factory DashboardChartsData.fromJson(Map<String, dynamic> json) {
    // Parse dari format RPC get_dashboard_charts_data
    // Format: revenue_chart.datasets[0].data, revenue_chart.labels, dll
    
    List<String> labels = [];
    List<double> revenueData = [];
    List<double> expensesData = [];
    List<double> profitData = [];
    List<int> customerGrowthData = [];
    List<int> customerTotalData = [];
    List<int> customerNetData = [];
    Map<String, int> invoiceStatusCounts = {'paid': 0, 'partially_paid': 0, 'unpaid': 0};

    try {
      // Parse revenue_chart
      final revenueChart = json['revenue_chart'] as Map<String, dynamic>?;
      if (revenueChart != null) {
        labels = (revenueChart['labels'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final datasets = revenueChart['datasets'] as List?;
        if (datasets != null && datasets.isNotEmpty) {
          // Dataset 0: Pendapatan
          revenueData = (datasets[0]['data'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
          // Dataset 1: Pengeluaran (jika ada)
          if (datasets.length > 1) {
            expensesData = (datasets[1]['data'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
          }
          // Dataset 2: Profit (jika ada)
          if (datasets.length > 2) {
            profitData = (datasets[2]['data'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
          }
        }
      }

      // Parse payment_status_chart
      final paymentChart = json['payment_status_chart'] as Map<String, dynamic>?;
      if (paymentChart != null) {
        final datasets = paymentChart['datasets'] as List?;
        if (datasets != null && datasets.isNotEmpty) {
          final data = datasets[0]['data'] as List?;
          if (data != null && data.length >= 3) {
            invoiceStatusCounts = {
              'paid': (data[0] as num).toInt(),
              'partially_paid': (data[1] as num).toInt(),
              'unpaid': (data[2] as num).toInt(),
            };
          }
        }
      }

      // Parse customer_growth_chart
      final growthChart = json['customer_growth_chart'] as Map<String, dynamic>?;
      if (growthChart != null) {
        final datasets = growthChart['datasets'] as List?;
        if (datasets != null && datasets.isNotEmpty) {
          customerGrowthData = (datasets[0]['data'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
          if (datasets.length > 1) {
            customerNetData = (datasets[1]['data'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
          }
        }
      }

      // Parse customer_total_chart
      final totalChart = json['customer_total_chart'] as Map<String, dynamic>?;
      if (totalChart != null) {
        final datasets = totalChart['datasets'] as List?;
        if (datasets != null && datasets.isNotEmpty) {
          customerTotalData = (datasets[0]['data'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
        }
      }
    } catch (e) {
      print('❌ Error parsing charts data: $e');
    }

    return DashboardChartsData(
      revenueData: revenueData,
      expensesData: expensesData,
      profitData: profitData,
      customerGrowthData: customerGrowthData,
      customerTotalData: customerTotalData,
      customerNetData: customerNetData,
      labels: labels,
      invoiceStatusCounts: invoiceStatusCounts,
    );
  }
}

class MonthlyRevenue {
  final String month;
  final double amount;

  MonthlyRevenue({required this.month, required this.amount});
}

class DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepository(this._supabase);

  /// Get dashboard statistics using RPC function
  Future<DashboardStats> getDashboardStats({
    int? month,
    int? year,
  }) async {
    try {
      final now = DateTime.now();
      final filterMonth = month ?? 0; // 0 = all months
      final filterYear = year ?? now.year;

      final response = await _supabase.rpc(
        'get_dashboard_stats',
        params: {
          'p_month': filterMonth,
          'p_year': filterYear,
        },
      );

      if (response == null || (response as List).isEmpty) {
        throw Exception('No data returned from get_dashboard_stats');
      }

      final data = (response as List).first as Map<String, dynamic>;
      return DashboardStats.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  /// Get dashboard charts data using RPC function
  Future<DashboardChartsData> getDashboardChartsData({int months = 6}) async {
    try {
      print('🔵 [DashboardRepo] Fetching charts data for $months months...');
      
      final response = await _supabase.rpc(
        'get_dashboard_charts_data',
        params: {'p_months': months},
      );

      if (response == null) {
        throw Exception('No data returned from get_dashboard_charts_data');
      }

      print('✅ [DashboardRepo] Charts data fetched successfully');
      return DashboardChartsData.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ [DashboardRepo] Charts data error: $e');
      
      // Fallback: Return empty data instead of throwing
      print('⚠️ [DashboardRepo] Using empty charts data as fallback');
      return DashboardChartsData(
        labels: [],
        revenueData: [],
        expensesData: [],
        profitData: [],
        customerGrowthData: [],
        customerTotalData: [],
        customerNetData: [],
        invoiceStatusCounts: {},
      );
    }
  }

  /// Get monthly revenue for chart (using charts data)
  Future<List<MonthlyRevenue>> getMonthlyRevenue({int months = 6}) async {
    try {
      final chartsData = await getDashboardChartsData(months: months);

      final List<MonthlyRevenue> monthlyData = [];
      for (int i = 0; i < chartsData.labels.length; i++) {
        monthlyData.add(MonthlyRevenue(
          month: chartsData.labels[i],
          amount: chartsData.revenueData[i],
        ));
      }

      return monthlyData;
    } catch (e) {
      throw Exception('Failed to fetch monthly revenue: $e');
    }
  }

  /// Get all customers using RPC function
  Future<List<ProfileModel>> getAllCustomers({
    String filter = 'all',
    String searchTerm = '',
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_all_customers',
        params: {
          'p_filter': filter,
          'p_search_term': searchTerm,
        },
      );

      if (response == null) {
        return [];
      }

      return (response as List)
          .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  /// Get recent invoices
  Future<List<InvoiceModel>> getRecentInvoices({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl)')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent invoices: $e');
    }
  }

  /// Get recent customers
  Future<List<ProfileModel>> getRecentCustomers({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'USER')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((e) => ProfileModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent customers: $e');
    }
  }

  /// Get customer by ID with package info
  Future<Map<String, dynamic>> getCustomerById(String customerId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*, packages(*)')
          .eq('id', customerId)
          .single();

      // Get user email using RPC
      String? email;
      try {
        final emailResponse = await _supabase.rpc(
          'get_user_email',
          params: {'user_id': customerId},
        );
        email = emailResponse as String?;
      } catch (e) {
        print('Failed to get user email: $e');
      }

      // Build customer data with package info
      final customerData = Map<String, dynamic>.from(response);
      customerData['email'] = email;
      
      // Extract package info
      if (response['packages'] != null) {
        customerData['package_name'] = response['packages']['package_name'];
        customerData['package_price'] = response['packages']['price'];
      }

      return customerData;
    } catch (e) {
      throw Exception('Failed to fetch customer: $e');
    }
  }

  /// Get customer invoices
  Future<List<InvoiceModel>> getCustomerInvoices(String customerId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch customer invoices: $e');
    }
  }
}
