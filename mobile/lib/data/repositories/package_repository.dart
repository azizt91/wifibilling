import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/package_model.dart';

class PackageRepository {
  final SupabaseClient _supabase;

  PackageRepository(this._supabase);

  /// Get all packages
  Future<List<PackageModel>> getPackages() async {
    try {
      final response = await _supabase
          .from('packages')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => PackageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch packages: $e');
    }
  }

  /// Get package by ID
  Future<PackageModel> getPackageById(int id) async {
    try {
      final response = await _supabase
          .from('packages')
          .select()
          .eq('id', id)
          .single();

      return PackageModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch package: $e');
    }
  }

  /// Create new package
  Future<PackageModel> createPackage({
    required String packageName,
    required double price,
    required int speedMbps,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('packages')
          .insert({
            'package_name': packageName,
            'price': price,
            'speed_mbps': speedMbps,
            if (description != null && description.isNotEmpty)
              'description': description,
          })
          .select()
          .single();

      return PackageModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create package: $e');
    }
  }

  /// Update package
  Future<PackageModel> updatePackage({
    required int id,
    required String packageName,
    required double price,
    required int speedMbps,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('packages')
          .update({
            'package_name': packageName,
            'price': price,
            'speed_mbps': speedMbps,
            'description': description,
          })
          .eq('id', id)
          .select()
          .single();

      return PackageModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update package: $e');
    }
  }

  /// Delete package
  Future<void> deletePackage(int id) async {
    try {
      await _supabase
          .from('packages')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete package: $e');
    }
  }

  /// Search packages
  Future<List<PackageModel>> searchPackages(String query) async {
    try {
      final response = await _supabase
          .from('packages')
          .select()
          .or('package_name.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => PackageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search packages: $e');
    }
  }
}
