import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_model.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';

class InvoiceRepository {
  final SupabaseClient _supabase;
  final CacheService _cacheService;
  final ConnectivityService _connectivityService;

  InvoiceRepository(
    this._supabase,
    this._cacheService,
    this._connectivityService,
  );

  // Get invoices by status with pagination
  Future<List<InvoiceModel>> getInvoices({
    required String status,
    int page = 1,
    int limit = 20,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    // Check if online
    final isOnline = await _connectivityService.checkConnection();

    // If offline, return cached data
    if (!isOnline) {
      final cached = _cacheService.getCachedInvoicesByStatus(status);
      if (cached.isNotEmpty) {
        return _applyLocalFilters(cached, searchQuery, startDate, endDate, page, limit);
      }
      throw Exception('No internet connection and no cached data available');
    }

    try {
      // Join with profiles to get customer name
      var queryBuilder = _supabase
          .from('invoices')
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl, whatsapp_number)');

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'invoice_period.ilike.%$searchQuery%',
        );
      }

      // Apply status filter - fix 'installment' to 'partially_paid'
      if (status != 'all') {
        final actualStatus = status == 'installment' ? 'partially_paid' : status;
        queryBuilder = queryBuilder.eq('status', actualStatus);
      }

      // Apply date range filter
      if (startDate != null) {
        queryBuilder = queryBuilder.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('created_at', endDate.toIso8601String());
      }

      // Apply pagination and ordering
      final start = (page - 1) * limit;
      final response = await queryBuilder
          .range(start, start + limit - 1)
          .order('created_at', ascending: false);
      final invoices = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();

      // Cache first page without filters
      if (page == 1 && searchQuery == null && startDate == null && endDate == null) {
        await _cacheService.cacheInvoicesByStatus(status, invoices);
      }

      return invoices;
    } catch (e) {
      // If online request fails, try cache
      final cached = _cacheService.getCachedInvoicesByStatus(status);
      if (cached.isNotEmpty) {
        return _applyLocalFilters(cached, searchQuery, startDate, endDate, page, limit);
      }
      throw Exception('Failed to fetch invoices: $e');
    }
  }

  // Get invoice count by status
  Future<int> getInvoiceCount({
    required String status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('invoices')
          .select('id');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'invoice_period.ilike.%$searchQuery%',
        );
      }

      if (status != 'all') {
        queryBuilder = queryBuilder.eq('status', status);
      }

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('created_at', endDate.toIso8601String());
      }

      final response = await queryBuilder;
      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get invoice count: $e');
    }
  }

  // Get single invoice by ID
  Future<InvoiceModel> getInvoiceById(String id) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl, whatsapp_number, address)')
          .eq('id', id)
          .single();

      return InvoiceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch invoice: $e');
    }
  }

  // Create new invoice
  Future<InvoiceModel> createInvoice({
    required String customerId,
    required double amount,
    required DateTime dueDate,
    String? description,
    String? notes,
  }) async {
    try {
      // Generate invoice number
      final now = DateTime.now();
      final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

      final response = await _supabase
          .from('invoices')
          .insert({
            'customer_id': customerId,
            'invoice_number': invoiceNumber,
            'amount': amount,
            'due_date': dueDate.toIso8601String(),
            'status': 'unpaid',
            'description': description,
            'notes': notes,
          })
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl, phone)')
          .single();

      return InvoiceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create invoice: $e');
    }
  }

  // Process payment (full or installment)
  Future<InvoiceModel> processPayment({
    required String invoiceId,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      // Get current invoice
      final invoice = await getInvoiceById(invoiceId);
      
      final totalPaid = (invoice.paidAmount ?? 0) + paidAmount;
      final remaining = invoice.amount - totalPaid;

      // Determine new status
      String newStatus;
      if (remaining <= 0) {
        newStatus = 'paid';
      } else if (totalPaid > 0) {
        newStatus = 'installment';
      } else {
        newStatus = 'unpaid';
      }

      // Update invoice
      final response = await _supabase
          .from('invoices')
          .update({
            'paid_amount': totalPaid,
            'status': newStatus,
            'paid_at': newStatus == 'paid' ? DateTime.now().toIso8601String() : null,
            'payment_method': paymentMethod,
            'notes': notes,
          })
          .eq('id', invoiceId)
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl, phone)')
          .single();

      return InvoiceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  // Update invoice
  Future<InvoiceModel> updateInvoice({
    required String id,
    double? amount,
    DateTime? dueDate,
    String? description,
    String? notes,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (amount != null) updates['amount'] = amount;
      if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
      if (description != null) updates['description'] = description;
      if (notes != null) updates['notes'] = notes;
      if (status != null) updates['status'] = status;

      final response = await _supabase
          .from('invoices')
          .update(updates)
          .eq('id', id)
          .select('*, profiles!invoices_customer_id_fkey(full_name, idpl, phone)')
          .single();

      return InvoiceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  // Delete invoice
  Future<void> deleteInvoice(String id) async {
    try {
      await _supabase.from('invoices').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }

  // Get invoice statistics
  Future<Map<String, dynamic>> getInvoiceStats() async {
    try {
      final response = await _supabase.from('invoices').select('status, amount, paid_amount');

      final invoices = response as List;
      
      final unpaid = invoices.where((i) => i['status'] == 'unpaid').length;
      final installment = invoices.where((i) => i['status'] == 'installment').length;
      final paid = invoices.where((i) => i['status'] == 'paid').length;

      final totalRevenue = invoices
          .where((i) => i['status'] == 'paid')
          .fold<double>(0, (sum, i) => sum + (i['amount'] as num).toDouble());

      final totalUnpaid = invoices
          .where((i) => i['status'] == 'unpaid')
          .fold<double>(0, (sum, i) => sum + (i['amount'] as num).toDouble());

      final totalInstallment = invoices
          .where((i) => i['status'] == 'installment')
          .fold<double>(0, (sum, i) {
            final amount = (i['amount'] as num).toDouble();
            final paidAmount = (i['paid_amount'] as num?)?.toDouble() ?? 0;
            return sum + (amount - paidAmount);
          });

      return {
        'unpaid_count': unpaid,
        'installment_count': installment,
        'paid_count': paid,
        'total_revenue': totalRevenue,
        'total_unpaid': totalUnpaid,
        'total_installment': totalInstallment,
      };
    } catch (e) {
      throw Exception('Failed to get invoice stats: $e');
    }
  }

  // Get invoices for a specific customer
  Future<List<InvoiceModel>> getCustomerInvoices(String customerId, {bool forceRefresh = false}) async {
    // Check if online
    final isOnline = await _connectivityService.checkConnection();

    // If offline, return cached data
    if (!isOnline) {
      final cached = _cacheService.getCachedCustomerInvoices(customerId);
      if (cached.isNotEmpty) {
        return cached;
      }
      throw Exception('No internet connection and no cached data available');
    }

    try {
      final response = await _supabase
          .from('invoices')
          .select('*')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      final invoices = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
      
      // Cache customer invoices
      await _cacheService.cacheCustomerInvoices(customerId, invoices);

      return invoices;
    } catch (e) {
      // If online request fails, try cache
      final cached = _cacheService.getCachedCustomerInvoices(customerId);
      if (cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Failed to fetch customer invoices: $e');
    }
  }

  // Helper: Apply local filters to cached invoices
  List<InvoiceModel> _applyLocalFilters(
    List<InvoiceModel> invoices,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    int page,
    int limit,
  ) {
    var filtered = invoices;

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((i) {
        final period = i.invoicePeriod.toLowerCase();
        return period.contains(query);
      }).toList();
    }

    // Apply date range filter
    if (startDate != null) {
      filtered = filtered.where((i) {
        return i.createdAt != null && i.createdAt!.isAfter(startDate);
      }).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((i) {
        return i.createdAt != null && i.createdAt!.isBefore(endDate);
      }).toList();
    }

    // Apply pagination
    final start = (page - 1) * limit;
    final end = start + limit;
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end > filtered.length ? filtered.length : end);
  }

  /// Create monthly invoices using RPC function
  Future<Map<String, dynamic>> createMonthlyInvoices() async {
    try {
      final response = await _supabase.rpc('create_monthly_invoices_v2');
      
      if (response == null) {
        throw Exception('No response from create_monthly_invoices_v2');
      }

      // Response format: {status: 'success', message: '...', created_count: X}
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to create monthly invoices: $e');
    }
  }

  /// Process installment payment using RPC function
  Future<Map<String, dynamic>> processInstallmentPayment({
    required String invoiceId,
    required double paymentAmount,
    required String adminName,
    String paymentMethod = 'cash',
    String note = '',
  }) async {
    try {
      final response = await _supabase.rpc('process_installment_payment', params: {
        'p_invoice_id': invoiceId,
        'p_payment_amount': paymentAmount,
        'p_admin_name': adminName,
        'p_payment_method': paymentMethod,
        'p_note': note,
      });

      if (response == null) {
        throw Exception('No response from process_installment_payment');
      }

      final result = response as Map<String, dynamic>;
      
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Payment processing failed');
      }

      return result;
    } catch (e) {
      throw Exception('Failed to process installment payment: $e');
    }
  }

  /// Mark invoice as fully paid
  Future<InvoiceModel> markAsPaid({
    required String invoiceId,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final invoice = await getInvoiceById(invoiceId);
      
      // Update invoice to paid status
      await _supabase.from('invoices').update({
        'status': 'paid',
        'amount_paid': invoice.totalDue ?? invoice.amount,
        'amount': 0, // Remaining amount
        'paid_at': DateTime.now().toIso8601String(),
        'payment_method': paymentMethod,
        'last_payment_date': DateTime.now().toIso8601String(),
      }).eq('id', invoiceId);

      // Fetch updated invoice
      return await getInvoiceById(invoiceId);
    } catch (e) {
      throw Exception('Failed to mark invoice as paid: $e');
    }
  }
}
