import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../data/providers/auth_provider.dart';

// Package Model
class PackageModel {
  final int id;
  final String packageName;
  final double price;
  final int? speedMbps;
  final String? description;

  PackageModel({required this.id, required this.packageName, required this.price, this.speedMbps, this.description});

  factory PackageModel.fromJson(Map<String, dynamic> json) => PackageModel(
    id: json['id'] as int,
    packageName: json['package_name'] as String,
    price: (json['price'] as num).toDouble(),
    speedMbps: json['speed_mbps'] as int?,
    description: json['description'] as String?,
  );
}

// Provider
final packagesProvider = FutureProvider.autoDispose<List<PackageModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('packages').select().order('created_at', ascending: false);
  return (response as List).map((e) => PackageModel.fromJson(e)).toList();
});

class AdminPackagesPage extends ConsumerStatefulWidget {
  const AdminPackagesPage({super.key});
  @override
  ConsumerState<AdminPackagesPage> createState() => _AdminPackagesPageState();
}

class _AdminPackagesPageState extends ConsumerState<AdminPackagesPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(packagesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: packages.when(
                data: (data) => _buildPackageList(_filterPackages(data)),
                loading: () => _buildSkeleton(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showPackageForm(context),
          backgroundColor: const Color(0xFF683FE4),
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  List<PackageModel> _filterPackages(List<PackageModel> packages) {
    if (_searchQuery.isEmpty) return packages;
    return packages.where((p) => 
      p.packageName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFFF9F8FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Paket Internet', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFFEAE8F3), borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF625095)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration.collapsed(hintText: 'Cari paket...', hintStyle: TextStyle(color: Color(0xFF625095))),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageList(List<PackageModel> packages) {
    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'Belum ada paket' : 'Paket tidak ditemukan', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(packagesProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: packages.length,
        itemBuilder: (_, i) => _buildPackageCard(packages[i]),
      ),
    );
  }

  Widget _buildPackageCard(PackageModel pkg) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(pkg.packageName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                      child: Text('ID: ${pkg.id}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pkg.speedMbps != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(16)),
                    child: Text('${pkg.speedMbps} Mbps', style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 8),
                Text(formatter.format(pkg.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(pkg.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
          Column(
            children: [
              _buildActionBtn(Icons.edit, const Color(0xFF3B82F6), const Color(0xFFDBEAFE), () => _showPackageForm(context, pkg)),
              const SizedBox(height: 8),
              _buildActionBtn(Icons.delete, const Color(0xFFEF4444), const Color(0xFFFEE2E2), () => _deletePackage(pkg)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 120,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _showPackageForm(BuildContext context, [PackageModel? pkg]) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PackageFormPage(package: pkg)));
    if (result == true) ref.invalidate(packagesProvider);
  }

  Future<void> _deletePackage(PackageModel pkg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Yakin ingin menghapus paket "${pkg.packageName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(supabaseClientProvider).from('packages').delete().eq('id', pkg.id);
      ref.invalidate(packagesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paket berhasil dihapus')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }
}


// Package Form Page
class PackageFormPage extends ConsumerStatefulWidget {
  final PackageModel? package;
  const PackageFormPage({super.key, this.package});
  @override
  ConsumerState<PackageFormPage> createState() => _PackageFormPageState();
}

class _PackageFormPageState extends ConsumerState<PackageFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _speedController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.package != null) {
      _nameController.text = widget.package!.packageName;
      _priceController.text = widget.package!.price.toInt().toString();
      _speedController.text = widget.package!.speedMbps?.toString() ?? '';
      _descController.text = widget.package!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _speedController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.package != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8FB),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)), onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Edit Paket' : 'Tambah Paket', style: const TextStyle(color: Color(0xFF110E1B), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField('Nama Paket', _nameController, 'Contoh: Paket Rumah 10 Mbps', required: true),
            const SizedBox(height: 16),
            _buildField('Harga (Rp)', _priceController, 'Contoh: 150000', keyboardType: TextInputType.number, required: true),
            const SizedBox(height: 16),
            _buildField('Kecepatan (Mbps)', _speedController, 'Contoh: 10', keyboardType: TextInputType.number, required: true),
            const SizedBox(height: 16),
            _buildField('Deskripsi', _descController, 'Deskripsi paket (opsional)', maxLines: 4),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF683FE4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Perbarui' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B)),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : null,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFFEAE8F3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF683FE4), width: 2)),
          ),
          validator: required ? (v) => v == null || v.isEmpty ? '$label wajib diisi' : null : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'package_name': _nameController.text.trim(),
        'price': double.parse(_priceController.text),
        'speed_mbps': int.tryParse(_speedController.text),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      };

      final supabase = ref.read(supabaseClientProvider);

      if (widget.package != null) {
        await supabase.from('packages').update(data).eq('id', widget.package!.id);
      } else {
        await supabase.from('packages').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.package != null ? 'Paket berhasil diperbarui' : 'Paket berhasil ditambahkan')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
