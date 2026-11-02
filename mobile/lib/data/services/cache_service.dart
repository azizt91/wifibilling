import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile_model.dart';
import '../models/invoice_model.dart';
import '../../core/services/hive_service.dart';

class CacheService {
  // Dashboard Stats Cache
  Future<void> cacheDashboardStats(Map<String, dynamic> stats) async {
    final box = Hive.box(HiveService.dashboardStatsBox);
    await box.put('stats', stats);
    await _updateCacheMeta('dashboard_stats');
  }

  Map<String, dynamic>? getCachedDashboardStats() {
    final box = Hive.box(HiveService.dashboardStatsBox);
    final stats = box.get('stats');
    if (stats != null) {
      return Map<String, dynamic>.from(stats);
    }
    return null;
  }

  // Customer List Cache
  Future<void> cacheCustomers(List<ProfileModel> customers) async {
    final box = Hive.box<ProfileModel>(HiveService.customersBox);
    await box.clear();
    for (var i = 0; i < customers.length; i++) {
      await box.put('customer_$i', customers[i]);
    }
    await _updateCacheMeta('customers');
  }

  List<ProfileModel> getCachedCustomers() {
    final box = Hive.box<ProfileModel>(HiveService.customersBox);
    return box.values.toList();
  }

  // Invoice List Cache
  Future<void> cacheInvoices(List<InvoiceModel> invoices) async {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    await box.clear();
    for (var i = 0; i < invoices.length; i++) {
      await box.put('invoice_$i', invoices[i]);
    }
    await _updateCacheMeta('invoices');
  }

  List<InvoiceModel> getCachedInvoices() {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    return box.values.toList();
  }

  // Cache by Status
  Future<void> cacheInvoicesByStatus(String status, List<InvoiceModel> invoices) async {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    // Clear previous invoices with this status
    final keysToDelete = box.keys.where((key) => key.toString().startsWith('invoice_${status}_')).toList();
    for (var key in keysToDelete) {
      await box.delete(key);
    }
    // Add new invoices
    for (var i = 0; i < invoices.length; i++) {
      await box.put('invoice_${status}_$i', invoices[i]);
    }
    await _updateCacheMeta('invoices_$status');
  }

  List<InvoiceModel> getCachedInvoicesByStatus(String status) {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    return box.keys
        .where((key) => key.toString().startsWith('invoice_${status}_'))
        .map((key) => box.get(key)!)
        .toList();
  }

  // Customer Invoices Cache
  Future<void> cacheCustomerInvoices(String customerId, List<InvoiceModel> invoices) async {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    // Clear previous customer invoices
    final keysToDelete = box.keys.where((key) => key.toString().startsWith('customer_invoice_${customerId}_')).toList();
    for (var key in keysToDelete) {
      await box.delete(key);
    }
    // Add new invoices
    for (var i = 0; i < invoices.length; i++) {
      await box.put('customer_invoice_${customerId}_$i', invoices[i]);
    }
    await _updateCacheMeta('customer_invoices_$customerId');
  }

  List<InvoiceModel> getCachedCustomerInvoices(String customerId) {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    return box.keys
        .where((key) => key.toString().startsWith('customer_invoice_${customerId}_'))
        .map((key) => box.get(key)!)
        .toList();
  }

  // Cache Meta (untuk track last update time)
  Future<void> _updateCacheMeta(String key) async {
    final box = Hive.box(HiveService.cacheMetaBox);
    await box.put(key, DateTime.now().toIso8601String());
  }

  DateTime? getCacheTime(String key) {
    final box = Hive.box(HiveService.cacheMetaBox);
    final timeStr = box.get(key);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }

  bool isCacheExpired(String key, {Duration maxAge = const Duration(hours: 1)}) {
    final cacheTime = getCacheTime(key);
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > maxAge;
  }

  // Clear specific cache
  Future<void> clearDashboardCache() async {
    final box = Hive.box(HiveService.dashboardStatsBox);
    await box.clear();
  }

  Future<void> clearCustomersCache() async {
    final box = Hive.box<ProfileModel>(HiveService.customersBox);
    await box.clear();
  }

  Future<void> clearInvoicesCache() async {
    final box = Hive.box<InvoiceModel>(HiveService.invoicesBox);
    await box.clear();
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    await HiveService.clearAllCache();
  }
}
