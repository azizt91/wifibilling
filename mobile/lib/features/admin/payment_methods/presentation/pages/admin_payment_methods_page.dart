import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../data/providers/auth_provider.dart';

// QRIS Settings Model
class QrisSettingsModel {
  final String? id;
  final String? qrisImageUrl;
  final bool showQris;

  QrisSettingsModel({
    this.id,
    this.qrisImageUrl,
    this.showQris = true,
  });
}

// QRIS Provider
final qrisSettingsProvider = FutureProvider.autoDispose<QrisSettingsModel>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.from('app_settings').select('id, qris_image_url, show_qris').maybeSingle();
    if (response == null) return QrisSettingsModel();
    return QrisSettingsModel(
      id: response['id']?.toString(),
      qrisImageUrl: response['qris_image_url']?.toString(),
      showQris: response['show_qris'] == true,
    );
  } catch (e) {
    debugPrint('Error loading QRIS settings: $e');
    return QrisSettingsModel();
  }
});

// Payment Method Model
class PaymentMethodModel {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final int sortOrder;
  final bool isActive;

  PaymentMethodModel({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountHolder: json['account_holder']?.toString() ?? '',
      sortOrder: (json['sort_order'] is int) ? json['sort_order'] : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == true,
    );
  }
}

// Provider
final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethodModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('payment_methods').select('*').order('sort_order', ascending: true);
  return (response as List).map((e) => PaymentMethodModel.fromJson(e)).toList();
});

class AdminPaymentMethodsPage extends ConsumerStatefulWidget {
  const AdminPaymentMethodsPage({super.key});
  @override
  ConsumerState<AdminPaymentMethodsPage> createState() => _AdminPaymentMethodsPageState();
}

class _AdminPaymentMethodsPageState extends ConsumerState<AdminPaymentMethodsPage> {
  File? _pickedQrisFile;
  String? _localQrisUrl;
  bool? _localShowQris;
  bool _isUploadingQris = false;
  bool _isUpdatingQris = false;

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final qrisAsync = ref.watch(qrisSettingsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: methodsAsync.when(
                data: (methods) => _buildContent(methods, qrisAsync.asData?.value),
                loading: () => _buildLoading(qrisAsync.asData?.value),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(context),
          backgroundColor: const Color(0xFF683FE4),
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Color(0xFF110E1B))),
              const Expanded(child: Text('Metode Pembayaran', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)))),
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<PaymentMethodModel> methodsList, QrisSettingsModel? qris) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(paymentMethodsProvider);
        ref.invalidate(qrisSettingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildQrisSection(qris),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Bank & E-Wallet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${methodsList.length} Akun',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF683FE4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (methodsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Belum ada rekening bank / e-wallet',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  const Text('Tap tombol + di bawah untuk menambahkan',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            )
          else
            ...methodsList.map((m) => _buildItem(m)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQrisSection(QrisSettingsModel? qrisSettings) {
    final showQris = _localShowQris ?? qrisSettings?.showQris ?? true;
    final qrisUrl = _localQrisUrl ?? qrisSettings?.qrisImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF683FE4), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembayaran QRIS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
                      ),
                      Text(
                        'Barcode QRIS untuk pembayaran tagihan',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showQris,
                  activeColor: const Color(0xFF683FE4),
                  onChanged: _isUpdatingQris ? null : (val) => _toggleQris(val, qrisSettings?.id),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Preview Area
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isUploadingQris
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Color(0xFF683FE4)),
                                SizedBox(height: 12),
                                Text('Mengunggah QRIS...', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : (_pickedQrisFile != null)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_pickedQrisFile!, fit: BoxFit.contain),
                              )
                            : (qrisUrl != null && qrisUrl.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      qrisUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                    ),
                                  )
                                : _buildPlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingQris ? null : () => _pickAndUploadQris(qrisSettings?.id),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      (qrisUrl != null && qrisUrl.isNotEmpty) ? 'Ganti Barcode QRIS' : 'Upload Barcode QRIS',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF683FE4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Format JPG atau PNG, ukuran maksimal 2MB',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 8),
        const Text(
          'Belum ada QRIS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Upload gambar QRIS usaha Anda',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _toggleQris(bool value, String? settingsId) async {
    setState(() {
      _localShowQris = value;
      _isUpdatingQris = true;
    });
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (settingsId != null) {
        await supabase.from('app_settings').update({'show_qris': value}).eq('id', settingsId);
      } else {
        await supabase.from('app_settings').upsert({'show_qris': value});
      }
      ref.invalidate(qrisSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'QRIS diaktifkan' : 'QRIS dinonaktifkan'),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status QRIS: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _localShowQris = !value);
    } finally {
      if (mounted) setState(() => _isUpdatingQris = false);
    }
  }

  Future<void> _pickAndUploadQris(String? settingsId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedQrisFile = file;
      _isUploadingQris = true;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final ext = file.path.split('.').last;
      final fileName = 'qris-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'qris/$fileName';

      await supabase.storage.from('avatars').upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final url = supabase.storage.from('avatars').getPublicUrl(filePath);

      if (settingsId != null) {
        await supabase.from('app_settings').update({
          'qris_image_url': url,
          'show_qris': _localShowQris ?? true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', settingsId);
      } else {
        await supabase.from('app_settings').upsert({
          'qris_image_url': url,
          'show_qris': _localShowQris ?? true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() => _localQrisUrl = url);
      ref.invalidate(qrisSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcode QRIS berhasil diperbarui!'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah QRIS: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingQris = false);
    }
  }

  Widget _buildItem(PaymentMethodModel method) {
    return GestureDetector(
      onTap: () => _showForm(context, method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: method.isActive ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: method.isActive ? const Color(0xFFE5E7EB) : Colors.grey[300]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF0F2F4), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance, color: Color(0xFF110E1B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          method.bankName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF110E1B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!method.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: const Text('Nonaktif', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(method.accountNumber, style: const TextStyle(fontSize: 13, color: Color(0xFF110E1B)), overflow: TextOverflow.ellipsis),
                  Text(method.accountHolder, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading([QrisSettingsModel? qris]) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQrisSection(qris),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 80,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showForm(BuildContext context, [PaymentMethodModel? method]) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _PaymentMethodFormPage(method: method)));
    if (result == true) ref.invalidate(paymentMethodsProvider);
  }
}

// Form Page
class _PaymentMethodFormPage extends ConsumerStatefulWidget {
  final PaymentMethodModel? method;
  const _PaymentMethodFormPage({this.method});
  @override
  ConsumerState<_PaymentMethodFormPage> createState() => _PaymentMethodFormPageState();
}

class _PaymentMethodFormPageState extends ConsumerState<_PaymentMethodFormPage> {
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _sortOrderController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  bool get isEdit => widget.method != null;

  @override
  void initState() {
    super.initState();
    if (widget.method != null) {
      _bankNameController.text = widget.method!.bankName;
      _accountNumberController.text = widget.method!.accountNumber;
      _accountHolderController.text = widget.method!.accountHolder;
      _sortOrderController.text = widget.method!.sortOrder.toString();
      _isActive = widget.method!.isActive;
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)), onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Edit Bank' : 'Tambah Bank Baru', style: const TextStyle(color: Color(0xFF110E1B), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Nama Bank/E-Wallet *', _bankNameController, 'BCA, BNI, DANA, GoPay, dll'),
                  _buildField('Nomor Rekening *', _accountNumberController, '1234567890', keyboardType: TextInputType.number),
                  _buildField('Nama Pemilik *', _accountHolderController, 'NAMA PEMILIK'),
                  _buildField('Urutan Tampilan', _sortOrderController, '1', keyboardType: TextInputType.number, hint: 'Urutan tampilan (1 = paling atas)'),
                  SwitchListTile(
                    title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Tampilkan di halaman customer', style: TextStyle(fontSize: 12)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeColor: const Color(0xFF683FE4),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFFEAE8F3), side: BorderSide.none, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('BATAL', style: TextStyle(color: Color(0xFF110E1B), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF501EE6), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _delete,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('HAPUS BANK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String placeholder, {String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_bankNameController.text.trim().isEmpty || _accountNumberController.text.trim().isEmpty || _accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mohon lengkapi semua field yang diperlukan')));
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final data = {
        'bank_name': _bankNameController.text.trim(),
        'account_number': _accountNumberController.text.trim(),
        'account_holder': _accountHolderController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isEdit) {
        await supabase.from('payment_methods').update(data).eq('id', widget.method!.id);
      } else {
        await supabase.from('payment_methods').insert(data);
      }

      scaffoldMessenger.showSnackBar(SnackBar(content: Text(isEdit ? 'Bank berhasil diupdate' : 'Bank berhasil ditambahkan'), backgroundColor: const Color(0xFF22C55E)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Bank'),
        content: Text('Yakin ingin menghapus ${widget.method!.bankName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(supabaseClientProvider).from('payment_methods').delete().eq('id', widget.method!.id);
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Bank berhasil dihapus'), backgroundColor: Color(0xFF22C55E)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
