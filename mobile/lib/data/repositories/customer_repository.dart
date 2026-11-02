import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';

class CustomerRepository {
  final SupabaseClient _supabase;
  final CacheService _cacheService;
  final ConnectivityService _connectivityService;

  CustomerRepository(
    this._supabase,
    this._cacheService,
    this._connectivityService,
  );

  // Get all customers with pagination
  Future<List<ProfileModel>> getCustomers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? statusFilter,
    String? packageFilter,
    bool forceRefresh = false,
  }) async {
    // Check if online
    final isOnline = await _connectivityService.checkConnection();

    // If offline or no filters, return cached data
    if (!isOnline || (!forceRefresh && page == 1 && searchQuery == null && statusFilter == null)) {
      final cached = _cacheService.getCachedCustomers();
      if (cached.isNotEmpty) {
        return _applyLocalFilters(cached, searchQuery, statusFilter, page, limit);
      }
      if (!isOnline) {
        throw Exception('No internet connection and no cached data available');
      }
    }

    try {
      var queryBuilder = _supabase
          .from('profiles')
          .select('*, packages(name, price, speed)')
          .eq('role', 'USER');

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'full_name.ilike.%$searchQuery%,idpl.ilike.%$searchQuery%,phone.ilike.%$searchQuery%',
        );
      }

      // Apply status filter
      if (statusFilter != null && statusFilter != 'all') {
        queryBuilder = queryBuilder.eq('status', statusFilter);
      }

      // Apply package filter
      if (packageFilter != null && packageFilter != 'all') {
        queryBuilder = queryBuilder.eq('package_id', packageFilter);
      }

      // Apply pagination and ordering
      final start = (page - 1) * limit;
      final response = await queryBuilder
          .range(start, start + limit - 1)
          .order('created_at', ascending: false);
      final customers = (response as List).map((e) => ProfileModel.fromJson(e)).toList();

      // Cache first page without filters
      if (page == 1 && searchQuery == null && statusFilter == null) {
        await _cacheService.cacheCustomers(customers);
      }

      return customers;
    } catch (e) {
      // If online request fails, try cache
      final cached = _cacheService.getCachedCustomers();
      if (cached.isNotEmpty) {
        return _applyLocalFilters(cached, searchQuery, statusFilter, page, limit);
      }
      throw Exception('Failed to fetch customers: $e');
    }
  }

  // Get customer count for pagination
  Future<int> getCustomerCount({
    String? searchQuery,
    String? statusFilter,
    String? packageFilter,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'USER');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'full_name.ilike.%$searchQuery%,idpl.ilike.%$searchQuery%,phone.ilike.%$searchQuery%',
        );
      }

      if (statusFilter != null && statusFilter != 'all') {
        queryBuilder = queryBuilder.eq('status', statusFilter);
      }

      if (packageFilter != null && packageFilter != 'all') {
        queryBuilder = queryBuilder.eq('package_id', packageFilter);
      }

      final response = await queryBuilder;
      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get customer count: $e');
    }
  }

  // Get single customer by ID
  Future<ProfileModel> getCustomerById(String id) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*, packages(name, price, speed)')
          .eq('id', id)
          .single();

      return ProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch customer: $e');
    }
  }

  // Create new customer (via Supabase Edge Function)
  Future<ProfileModel> createCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
    required String packageId,
    String? latitude,
    String? longitude,
    String? ipStaticPppoe,
    String? notes,
  }) async {
    try {
      // Call Supabase Edge Function to create user + profile
      final response = await _supabase.functions.invoke(
        'create-customer',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone': phone,
          'address': address,
          'package_id': packageId,
          'latitude': latitude,
          'longitude': longitude,
          'ip_static_pppoe': ipStaticPppoe,
          'notes': notes,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to create customer');
      }

      return ProfileModel.fromJson(response.data['profile']);
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  // Update customer
  Future<ProfileModel> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? address,
    String? packageId,
    String? status,
    String? latitude,
    String? longitude,
    String? ipStaticPppoe,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address;
      if (packageId != null) updates['package_id'] = packageId;
      if (status != null) updates['status'] = status;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (ipStaticPppoe != null) updates['ip_static_pppoe'] = ipStaticPppoe;
      if (notes != null) updates['notes'] = notes;

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', id)
          .select('*, packages(name, price, speed)')
          .single();

      return ProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  // Delete customer (via Supabase Edge Function)
  Future<void> deleteCustomer(String id) async {
    try {
      final response = await _supabase.functions.invoke(
        'delete-user',
        body: {'user_id': id},
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to delete customer');
      }
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }

  // Toggle customer status
  Future<ProfileModel> toggleCustomerStatus(String id, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'AKTIF' ? 'NONAKTIF' : 'AKTIF';
      return await updateCustomer(id: id, status: newStatus);
    } catch (e) {
      throw Exception('Failed to toggle status: $e');
    }
  }

  // Get customer statistics
  Future<Map<String, int>> getCustomerStats() async {
    // Check if online
    final isOnline = await _connectivityService.checkConnection();

    if (!isOnline) {
      // Return stats from cached customers
      final cached = _cacheService.getCachedCustomers();
      if (cached.isNotEmpty) {
        final active = cached.where((c) => c.status == 'AKTIF').length;
        final inactive = cached.where((c) => c.status == 'NONAKTIF').length;
        return {
          'total': cached.length,
          'active': active,
          'inactive': inactive,
        };
      }
      throw Exception('No internet connection and no cached data available');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('status')
          .eq('role', 'USER');

      final customers = response as List;
      final active = customers.where((c) => c['status'] == 'AKTIF').length;
      final inactive = customers.where((c) => c['status'] == 'NONAKTIF').length;

      return {
        'total': customers.length,
        'active': active,
        'inactive': inactive,
      };
    } catch (e) {
      // Try cache on error
      final cached = _cacheService.getCachedCustomers();
      if (cached.isNotEmpty) {
        final active = cached.where((c) => c.status == 'AKTIF').length;
        final inactive = cached.where((c) => c.status == 'NONAKTIF').length;
        return {
          'total': cached.length,
          'active': active,
          'inactive': inactive,
        };
      }
      throw Exception('Failed to fetch customer stats: $e');
    }
  }

  // Helper: Apply local filters to cached data
  List<ProfileModel> _applyLocalFilters(
    List<ProfileModel> customers,
    String? searchQuery,
    String? statusFilter,
    int page,
    int limit,
  ) {
    var filtered = customers;

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = c.fullName?.toLowerCase() ?? '';
        final idpl = c.idpl?.toLowerCase() ?? '';
        return name.contains(query) || idpl.contains(query);
      }).toList();
    }

    // Apply status filter
    if (statusFilter != null && statusFilter != 'all') {
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    }

    // Apply pagination
    final start = (page - 1) * limit;
    final end = start + limit;
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end > filtered.length ? filtered.length : end);
  }
}
