import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../../../../core/utils/csv_file_helper.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/dashboard_provider.dart';

class CsvImportPage extends ConsumerStatefulWidget {
  const CsvImportPage({super.key});
  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  List<Map<String, dynamic>> _parsedData = [];
  bool _isLoading = false;
  bool _isImporting = false;
  int _successCount = 0;
  int _failedCount = 0;
  List<String> _errorMessages = [];
  double _progress = 0;
  String _fileName = '';

  final List<String> _requiredFields = [
    'full_name', 'address', 'whatsapp_number', 'amount'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Import CSV', style: TextStyle(color: Color(0xFF110E1B), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildUploadSection(),
            if (_parsedData.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPreviewSection(),
            ],
            if (_isImporting) ...[
              const SizedBox(height: 16),
              _buildProgressSection(),
            ],
            if (_successCount > 0 || _failedCount > 0) ...[
              const SizedBox(height: 16),
              _buildResultSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              const Text('Download Template CSV', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan template CSV untuk memastikan format data yang benar.',
            style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _isLoading || _isImporting ? null : _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(
              _fileName.isNotEmpty ? Icons.check_circle : Icons.upload_file,
              size: 48,
              color: _fileName.isNotEmpty ? const Color(0xFF22C55E) : const Color(0xFF683FE4),
            ),
            const SizedBox(height: 12),
            Text(
              _fileName.isNotEmpty ? _fileName : 'Tap untuk pilih file CSV',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _fileName.isNotEmpty ? const Color(0xFF22C55E) : const Color(0xFF110E1B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _fileName.isNotEmpty ? 'Tap untuk ganti file' : 'Maksimal 500 baris data',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Preview Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${_parsedData.length} baris', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
                  columns: _parsedData.isNotEmpty
                      ? _parsedData.first.keys.map((k) => DataColumn(label: Text(k, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList()
                      : [],
                  rows: _parsedData.take(5).map((row) {
                    return DataRow(
                      cells: row.values.map((v) => DataCell(Text(v?.toString() ?? '-', style: const TextStyle(fontSize: 12)))).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (_parsedData.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('... dan ${_parsedData.length - 5} baris lainnya', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isImporting ? null : _startImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF683FE4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isImporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mulai Import'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('Mengimport data...', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress, backgroundColor: const Color(0xFFEAE8F3), valueColor: const AlwaysStoppedAnimation(Color(0xFF683FE4))),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hasil Import', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('$_successCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                      const Text('Berhasil', style: TextStyle(color: Color(0xFF22C55E))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('$_failedCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                      const Text('Gagal', style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  const SizedBox(height: 8),
                  ..._errorMessages.take(10).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                  )),
                  if (_errorMessages.length > 10)
                    Text('... dan ${_errorMessages.length - 10} error lainnya', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ref.invalidate(allCustomersProvider);
                Navigator.pop(context);
              },
              child: const Text('Selesai'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    final headers = [
      'full_name',
      'whatsapp_number',
      'address',
      'amount',
      'installation_date',
      'device_type',
      'ip_static_pppoe',
      'email',
      'password',
    ];

    final sampleData = [
      ['Budi Santoso', '08123456789', 'Jl. Merdeka No 1 RT 02 RW 03 Bandung', '150000', '2024-01-15', 'ONT ZTE F609', '192.168.1.100', '', ''],
      ['Siti Aminah', '08198765432', 'Jl. Sudirman No 25 RT 01 RW 02 Jakarta', '150000', '2024-03-20', 'ONT Huawei HG8245H', '192.168.1.101', '', ''],
      ['Ahmad Wijaya', '08111222333', 'Jl. Asia Afrika No 3 RT 05 RW 01 Surabaya', '150000', '2023-12-01', 'Router Mikrotik RB750', '', '', ''],
      ['Rina Suryani', '08567891234', 'Jl. Gatot Subroto No 12 RT 03 RW 04 Semarang', '200000', '2024-02-10', 'ONT ZTE F660', '192.168.1.102', '', ''],
      ['Dedi Kurniawan', '08234567890', 'Jl. Diponegoro No 88 RT 02 RW 01 Yogyakarta', '150000', '2023-11-05', 'ONT Fiberhome AN5506', '192.168.1.103', '', ''],
    ];

    final csvContent = const ListToCsvConverter().convert([headers, ...sampleData]);

    final savedPath = await CsvFileHelper.saveCsv(
      fileName: 'template_import_pelanggan.csv',
      content: csvContent,
    );

    if (!mounted) return;

    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template CSV berhasil didownload:\n$savedPath'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template CSV disalin ke clipboard.'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        var csvString = utf8.decode(bytes);
        // Hapus BOM UTF-8 jika ada agar tidak merusak nama kolom pertama
        if (csvString.startsWith('\uFEFF')) {
          csvString = csvString.substring(1);
        }
        final rows = const CsvToListConverter().convert(csvString);

        if (rows.isEmpty) {
          _showError('File CSV kosong');
          return;
        }

        if (rows.length > 501) {
          _showError('Maksimal 500 baris data (tidak termasuk header)');
          return;
        }

        final headers = rows.first
            .map((e) => e.toString().trim().replaceFirst('\uFEFF', ''))
            .toList();
        final data = <Map<String, dynamic>>[];

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          final map = <String, dynamic>{};
          for (var j = 0; j < headers.length && j < row.length; j++) {
            map[headers[j]] = row[j]?.toString().trim() ?? '';
          }
          data.add(map);
        }

        // Validate required fields
        final missingFields = _requiredFields.where((f) => !headers.contains(f)).toList();
        if (missingFields.isNotEmpty) {
          _showError('Field wajib tidak ditemukan: ${missingFields.join(", ")}');
          return;
        }

        setState(() {
          _parsedData = data;
          _fileName = result.files.single.name;
          _successCount = 0;
          _failedCount = 0;
          _errorMessages = [];
        });
      }
    } catch (e) {
      _showError('Gagal membaca file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startImport() async {
    if (_parsedData.isEmpty) return;

    // Validate data
    final errors = _validateData();
    if (errors.isNotEmpty) {
      _showError('Data tidak valid:\n${errors.take(5).join("\n")}');
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = 0;
      _successCount = 0;
      _failedCount = 0;
      _errorMessages = [];
    });

    // Generate IDPLs
    final idpls = await _generateIdpls(_parsedData.length);

      // Ambil daftar paket untuk auto-match dengan amount
      List<dynamic> activePackages = [];
      try {
        final pkgsRes = await ref.read(supabaseClientProvider).from('packages').select('id, price');
        activePackages = pkgsRes as List<dynamic>;
      } catch (e) {
        debugPrint('Failed to load packages for auto-matching: $e');
      }

    for (var i = 0; i < _parsedData.length; i++) {
      final row = _parsedData[i];
      final idpl = idpls[i];

      try {
          await _importSingleCustomer(row, idpl, packages: activePackages);
        _successCount++;
      } catch (e) {
        _failedCount++;
        _errorMessages.add('Baris ${i + 2}: $e');
      }

      setState(() => _progress = (i + 1) / _parsedData.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() => _isImporting = false);

    if (_successCount > 0) {
      ref.invalidate(allCustomersProvider);
    }
  }

  List<String> _validateData() {
    final errors = <String>[];
    // Regex validasi email standar (sama dengan implementasi web csv-import.js)
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    for (var i = 0; i < _parsedData.length; i++) {
      final row = _parsedData[i];
      final rowNum = i + 2;

      for (final field in _requiredFields) {
        if (row[field] == null || row[field].toString().trim().isEmpty) {
          errors.add('Baris $rowNum: $field tidak boleh kosong');
        }
      }

      // Validate amount
      final amount = double.tryParse(row['amount']?.toString() ?? '');
      if (amount == null || amount <= 0) {
        errors.add('Baris $rowNum: Nominal tagihan (amount) harus berupa angka valid');
      }

      // Optional email validation if provided
      final email = row['email']?.toString().trim() ?? '';
      if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
        errors.add('Baris $rowNum: Format email tidak valid');
      }

      // Optional password validation if provided
      final password = row['password']?.toString().trim() ?? '';
      if (password.isNotEmpty && password.length < 6) {
        errors.add('Baris $rowNum: Password minimal 6 karakter');
      }
    }
    return errors;
  }

  Future<List<String>> _generateIdpls(int count) async {
    final supabase = ref.read(supabaseClientProvider);
    int baseIdpl = 1;

    try {
      final response = await supabase.from('profiles').select('idpl').like('idpl', 'CST%');
      final profiles = response as List;

      if (profiles.isNotEmpty) {
        final numbers = profiles
            .map((p) => int.tryParse((p['idpl'] as String).replaceAll('CST', '')) ?? 0)
            .where((n) => n > 0)
            .toList();

        if (numbers.isNotEmpty) {
          baseIdpl = numbers.reduce((a, b) => a > b ? a : b) + 1;
        }
      }
    } catch (e) {
      debugPrint('Error getting last IDPL: $e');
    }

    return List.generate(count, (i) => 'CST${(baseIdpl + i).toString().padLeft(3, '0')}');
  }

  Future<void> _importSingleCustomer(Map<String, dynamic> row, String idpl, {List<dynamic>? packages}) async {
    final supabase = ref.read(supabaseClientProvider);
    const photoUrl = 'assets/avatar_male.svg';

    String? installationDate;
    final dateStr = row['installation_date']?.toString().trim() ?? '';
    if (dateStr.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      installationDate = DateTime.parse(dateStr).toIso8601String();
    } else {
      installationDate = DateTime.now().toIso8601String();
    }

    final amountVal = double.tryParse(row['amount']?.toString() ?? '') ?? 0;
    
    // Auto-detect package_id from amount if omitted
    int? packageId = int.tryParse(row['package_id']?.toString() ?? '');
    if (packageId == null && packages != null && packages.isNotEmpty) {
      final matched = packages.firstWhere(
        (p) => (p['price'] as num?)?.toDouble() == amountVal,
        orElse: () => null,
      );
      if (matched != null) {
        packageId = matched['id'] as int?;
      } else {
        packageId = packages.first['id'] as int?;
      }
    }

    final emailVal = (row['email']?.toString().trim().isNotEmpty == true)
        ? row['email'].toString().trim()
        : '${idpl.toLowerCase()}@wifi.id';

    final passwordVal = (row['password']?.toString().trim().isNotEmpty == true)
        ? row['password'].toString().trim()
        : '123456';

    final customerData = {
      'email': emailVal,
      'password': passwordVal,
      'full_name': row['full_name']?.toString().trim(),
      'address': row['address']?.toString().trim(),
      'whatsapp_number': row['whatsapp_number']?.toString().trim(),
      'status': (row['status'] != null && row['status'].toString().trim().isNotEmpty)
          ? row['status'].toString().trim().toUpperCase()
          : 'AKTIF',
      'device_type': row['device_type']?.toString().trim(),
      'ip_static_pppoe': row['ip_static_pppoe']?.toString().trim(),
      'photo_url': photoUrl,
      'installation_date': installationDate,
      'package_id': packageId,
      'amount': amountVal,
      'latitude': double.tryParse(row['latitude']?.toString() ?? ''),
      'longitude': double.tryParse(row['longitude']?.toString() ?? ''),
      'idpl': idpl,
    };

    final response = await supabase.functions.invoke('create-customer', body: customerData);

    if (response.data != null && response.data['error'] != null) {
      throw Exception(response.data['error']);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
}
