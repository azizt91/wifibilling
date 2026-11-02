import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../core/widgets/app_avatar.dart';

class AdminProfilePage extends ConsumerStatefulWidget {
  const AdminProfilePage({super.key});
  @override
  ConsumerState<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends ConsumerState<AdminProfilePage> {
  bool _isEditMode = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: currentUser.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User tidak ditemukan'));
            }
            return _isEditMode ? _buildEditView(user) : _buildProfileView(user);
          },
          loading: () => _buildLoadingView(),
          error: (error, stack) => _buildErrorView(error.toString()),
        ),
      ),
    );
  }

  Widget _buildProfileView(dynamic user) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
              ),
            ),
            // Avatar Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickAndUploadImage(user),
                    child: Stack(
                      children: [
                        AppAvatar(
                          photoUrl: user.photoUrl,
                          name: user.fullName,
                          size: 128,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.edit, size: 18, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName ?? 'Admin',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? '',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF625095)),
                  ),
                ],
              ),
            ),
            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuCard(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profil',
                    onTap: () {
                      _nameController.text = user.fullName ?? '';
                      _emailController.text = user.email ?? '';
                      _passwordController.clear();
                      setState(() => _isEditMode = true);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan Aplikasi',
                    onTap: () => context.push('/admin/settings'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.credit_card_outlined,
                    title: 'Metode Pembayaran',
                    onTap: () => context.push('/admin/payment-methods'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.description_outlined,
                    title: 'Laporan',
                    onTap: () => context.push('/admin/reports'),
                  ),
                ],
              ),
            ),
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF683FE4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B7280), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEditView(dynamic user) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _confirmBack(),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Edit Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Lengkap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    enabled: false,
                    style: TextStyle(color: Colors.grey[600]),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Email akun tidak dapat diubah (digunakan sebagai identitas login).', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  const Text('Password Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Kosongkan jika tidak ingin mengubah',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _confirmBack(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAE8F3),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CANCEL', style: TextStyle(color: Color(0xFF110E1B), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveProfile(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF501EE6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingView() {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                ),
                const SizedBox(height: 16),
                Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 200, height: 16, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text('Gagal memuat profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4), foregroundColor: Colors.white),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(dynamic user) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      
      if (pickedFile == null) return;

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Mengunggah foto...')));

      final supabase = ref.read(supabaseClientProvider);
      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      await supabase.from('profiles').update({'photo_url': publicUrl}).eq('id', user.id);

      ref.invalidate(currentUserProvider);

      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Foto profil berhasil diperbarui'), backgroundColor: Color(0xFF22C55E)));
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal mengunggah foto: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _saveProfile(dynamic user) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final newName = _nameController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (newName.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong')));
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Password baru harus minimal 6 karakter')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Update profile name
      await supabase.from('profiles').update({'full_name': newName}).eq('id', user.id);

      // Update password if changed
      if (newPassword.isNotEmpty) {
        await supabase.auth.updateUser(UserAttributes(
          password: newPassword,
        ));
      }

      ref.invalidate(currentUserProvider);

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Color(0xFF22C55E)));
      setState(() => _isEditMode = false);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmBack() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin kembali? Perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isEditMode = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4)),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authControllerProvider).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }
}
