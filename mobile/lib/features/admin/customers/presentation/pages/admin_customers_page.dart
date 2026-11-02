import 'package:cached_network_image/cached_network_image.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../core/utils/csv_file_helper.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/dashboard_provider.dart';
import '../../../packages/presentation/pages/admin_packages_page.dart';
import 'customer_detail_page.dart';
import 'customer_form_page.dart' as form;
import 'csv_import_page.dart';

class AdminCustomersPage extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  const AdminCustomersPage({super.key, this.initialStatusFilter});
  @override
  ConsumerState<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends ConsumerState<AdminCustomersPage> {
  final _searchController = TextEditingController();
  String _currentFilter = 'all';
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    // Set initial filter from parameter
    if (widget.initialStatusFilter != null) {
      if (widget.initialStatusFilter == 'AKTIF') {
        _currentFilter = 'active';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(customersFilterProvider.notifier).state = 'active';
        });
      } else if (widget.initialStatusFilter == 'NONAKTIF') {
        _currentFilter = 'inactive';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(customersFilterProvider.notifier).state = 'inactive';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String filter) {
    setState(() => _currentFilter = filter);
    ref.read(customersFilterProvider.notifier).state = filter;
  }

  void _onSearchChanged(String value) {
    ref.read(customersSearchProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(customersSearchProvider.notifier).state = '';
  }

  void _toggleFab() => setState(() => _isFabExpanded = !_isFabExpanded);
  void _closeFab() { if (_isFabExpanded) setState(() => _isFabExpanded = false); }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(allCustomersProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(allCustomersProvider),
                    child: customers.when(
                      data: (data) => _buildCustomerList(data),
                      loading: () => _buildSkeletonList(),
                      error: (e, _) => _buildError(e.toString()),
                    ),
                  ),
                ),
              ],
            ),
            _buildFabMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF9F8FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text(
                    'Pelanggan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF110E1B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, color: Color(0xFF683FE4), size: 24),
                    tooltip: 'Export CSV',
                    onPressed: _exportCustomersCsv,
                  ),
                ],
              ),
            ),
            // Search Bar - Single Pills Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8F3),
                  borderRadius: BorderRadius.circular(9999), // Full rounded
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF625095), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF110E1B)),
                        cursorColor: const Color(0xFF625095),
                        decoration: const InputDecoration(
                          hintText: 'Cari pelanggan...',
                          hintStyle: TextStyle(color: Color(0xFF625095), fontSize: 16),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clearSearch,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Filter Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _buildFilterPill('all', 'Semua'),
                  const SizedBox(width: 12),
                  _buildFilterPill('active', 'Aktif'),
                  const SizedBox(width: 12),
                  _buildFilterPill('inactive', 'Tidak Aktif'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String value, String label) {
    final isActive = _currentFilter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF683FE4) : const Color(0xFFEAE8F3),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF110E1B),
          ),
        ),
      ),
    );
  }


  Widget _buildCustomerList(List<dynamic> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 96, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Tidak ada pelanggan ditemukan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            const Text('Coba ubah filter atau kata kunci pencarian',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: data.length,
      itemBuilder: (context, index) => _buildCustomerItem(data[index]),
    );
  }

  Widget _buildCustomerItem(dynamic customer) {
    final String status = customer.status ?? '';
    final String fullName = customer.fullName ?? '-';
    final String? photoUrl = customer.photoUrl;
    final String customerId = customer.id;
    final DateTime? installationDate = customer.installationDate;
    final DateTime? churnDate = customer.churnDate;

    final isActive = status == 'AKTIF';
    final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

    String dateInfo;
    if (!isActive) {
      dateInfo = 'Cabut: ${churnDate != null ? dateFormat.format(churnDate) : "Belum diatur"}';
    } else {
      dateInfo = 'Terdaftar: ${installationDate != null ? dateFormat.format(installationDate) : "N/A"}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (context) => CustomerDetailPage(customerId: customerId),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
        ),
        child: Row(
          children: [
            // Avatar using AppAvatar (supports default avatar SVG & remote URL)
            AppAvatar(
              photoUrl: photoUrl,
              name: fullName,
              size: 56,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF110E1B)),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(dateInfo, style: const TextStyle(fontSize: 14, color: Color(0xFF625095))),
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isActive ? 'Aktif' : 'Cabut',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: 10,
        itemBuilder: (_, __) => _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          Container(width: 56, height: 56, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text('Gagal memuat data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(allCustomersProvider),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4), foregroundColor: Colors.white),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFabMenu() {
    return Stack(
      children: [
        if (_isFabExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeFab,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
        Positioned(
          right: 20,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isFabExpanded) ...[
                _buildFabMenuItem(label: 'Export CSV', icon: Icons.file_download_outlined, onTap: () {
                  _closeFab();
                  _exportCustomersCsv();
                }),
                const SizedBox(height: 12),
                _buildFabMenuItem(label: 'Kelola Paket', icon: Icons.inventory_2_outlined, onTap: () {
                  _closeFab();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPackagesPage()));
                }),
                const SizedBox(height: 12),
                _buildFabMenuItem(label: 'Import CSV', icon: Icons.upload_file, onTap: () {
                  _closeFab();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CsvImportPage()));
                }),
                const SizedBox(height: 12),
                _buildFabMenuItem(label: 'Tambah Pelanggan', icon: Icons.person_add, onTap: () {
                  _closeFab();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const form.CustomerFormPage()));
                }),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF5324E0)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF683FE4).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Icon(_isFabExpanded ? Icons.close : Icons.info_outline, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFabMenuItem({required String label, required IconData icon, required VoidCallback onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: const Color(0xFF683FE4), size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCustomersCsv() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 16),
            Text('Mengekspor data pelanggan...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('profiles')
          .select('*, packages(price)')
          .eq('role', 'USER')
          .order('created_at', ascending: true);

      final profiles = List<Map<String, dynamic>>.from(response as List);

      if (profiles.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data pelanggan untuk diekspor.'),
            backgroundColor: Color(0xFFCA8A04),
          ),
        );
        return;
      }

      final headers = [
        'email',
        'password',
        'full_name',
        'address',
        'whatsapp_number',
        'status',
        'package_id',
        'amount',
        'installation_date',
        'latitude',
        'longitude',
        'device_type',
        'ip_static_pppoe',
      ];

      final rows = profiles.map((p) {
        final email = p['email'] ?? (p['idpl'] != null ? '${p['idpl'].toString().toLowerCase()}@wifi.id' : '');
        final password = '';
        final fullName = p['full_name'] ?? '';
        final address = p['address'] ?? '';
        final whatsapp = p['whatsapp_number'] ?? '';
        final status = p['status'] ?? 'AKTIF';
        final packageId = p['package_id']?.toString() ?? '';
        final amount = p['packages'] != null
            ? (p['packages']['price']?.toString() ?? '')
            : (p['amount']?.toString() ?? '');
        final installDate = p['installation_date'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(p['installation_date'].toString()))
            : '';
        final lat = p['latitude']?.toString() ?? '';
        final lng = p['longitude']?.toString() ?? '';
        final device = p['device_type'] ?? '';
        final ip = p['ip_static_pppoe'] ?? '';

        return [
          email,
          password,
          fullName,
          address,
          whatsapp,
          status,
          packageId,
          amount,
          installDate,
          lat,
          lng,
          device,
          ip,
        ];
      }).toList();

      final csvContent = const ListToCsvConverter().convert([headers, ...rows]);
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'data_pelanggan_$dateStr.csv';

      final savedPath = await CsvFileHelper.saveCsv(
        fileName: fileName,
        content: csvContent,
      );

      scaffoldMessenger.hideCurrentSnackBar();

      if (savedPath != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Export CSV berhasil:\n$savedPath'),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Data CSV disalin ke clipboard.'),
            backgroundColor: Color(0xFF3B82F6),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor CSV: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}


