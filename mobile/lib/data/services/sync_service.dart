import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';
import '../repositories/customer_repository.dart';
import '../repositories/invoice_repository.dart';
import '../providers/cache_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/invoice_provider.dart';

class SyncService {
  final ConnectivityService _connectivityService;
  final CacheService _cacheService;
  final CustomerRepository _customerRepository;
  final InvoiceRepository _invoiceRepository;
  
  StreamSubscription? _connectionSubscription;
  bool _isSyncing = false;

  SyncService({
    required ConnectivityService connectivityService,
    required CacheService cacheService,
    required CustomerRepository customerRepository,
    required InvoiceRepository invoiceRepository,
  })  : _connectivityService = connectivityService,
        _cacheService = cacheService,
        _customerRepository = customerRepository,
        _invoiceRepository = invoiceRepository;

  void startListening() {
    _connectionSubscription = _connectivityService.connectionStatus.listen((isOnline) {
      if (isOnline && !_isSyncing) {
        _syncData();
      }
    });
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    print('🔄 Starting data sync...');

    try {
      // Check if cache is expired (older than 1 hour)
      final shouldSyncCustomers = _cacheService.isCacheExpired('customers', maxAge: const Duration(hours: 1));
      final shouldSyncInvoices = _cacheService.isCacheExpired('invoices_unpaid', maxAge: const Duration(hours: 1));

      // Sync customers if needed
      if (shouldSyncCustomers) {
        print('📥 Syncing customers...');
        final customers = await _customerRepository.getCustomers(
          page: 1,
          limit: 100,
          forceRefresh: true,
        );
        await _cacheService.cacheCustomers(customers);
        print('✅ Customers synced: ${customers.length} items');
      }

      // Sync invoices if needed
      if (shouldSyncInvoices) {
        print('📥 Syncing invoices...');
        
        // Sync unpaid invoices
        final unpaidInvoices = await _invoiceRepository.getInvoices(
          status: 'unpaid',
          page: 1,
          limit: 100,
          forceRefresh: true,
        );
        await _cacheService.cacheInvoicesByStatus('unpaid', unpaidInvoices);
        print('✅ Unpaid invoices synced: ${unpaidInvoices.length} items');

        // Sync installment invoices
        final installmentInvoices = await _invoiceRepository.getInvoices(
          status: 'installment',
          page: 1,
          limit: 100,
          forceRefresh: true,
        );
        await _cacheService.cacheInvoicesByStatus('installment', installmentInvoices);
        print('✅ Installment invoices synced: ${installmentInvoices.length} items');

        // Sync paid invoices
        final paidInvoices = await _invoiceRepository.getInvoices(
          status: 'paid',
          page: 1,
          limit: 100,
          forceRefresh: true,
        );
        await _cacheService.cacheInvoicesByStatus('paid', paidInvoices);
        print('✅ Paid invoices synced: ${paidInvoices.length} items');
      }

      print('✅ Data sync completed!');
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> forceSyncAll() async {
    print('🔄 Force syncing all data...');
    await _syncData();
  }

  void stopListening() {
    _connectionSubscription?.cancel();
  }

  void dispose() {
    stopListening();
  }
}

// Sync Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    connectivityService: ref.watch(connectivityServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
    customerRepository: ref.watch(customerRepositoryProvider),
    invoiceRepository: ref.watch(invoiceRepositoryProvider),
  );
  
  // Start listening to connection changes
  service.startListening();
  
  // Dispose when provider is disposed
  ref.onDispose(() => service.dispose());
  
  return service;
});
