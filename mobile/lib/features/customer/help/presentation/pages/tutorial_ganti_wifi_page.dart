import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TutorialGantiWifiPage extends StatelessWidget {
  const TutorialGantiWifiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Panduan Ganti WiFi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF110E1B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Berikut adalah panduan langkah demi langkah untuk mengganti nama (SSID) dan password WiFi untuk beberapa model modem yang umum digunakan di jaringan kami.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF110E1B), height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pastikan Anda memilih panduan yang sesuai dengan model modem WiFi yang Anda gunakan di rumah. Informasi model modem biasanya tertera pada stiker di bagian bawah atau belakang perangkat.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF110E1B), height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    _buildSection(
                      'TOTOLINK N200RE (V.4 & V.5)',
                      [
                        'Hubungkan perangkat Anda (komputer atau HP) ke modem TOTOLINK, baik melalui kabel LAN atau WiFi.',
                        'Buka browser (Chrome, Firefox, dll.) dan ketik alamat IP 192.168.0.1 atau 192.168.1.1 di address bar, lalu tekan Enter.',
                        'Anda akan diminta login. Masukkan username admin dan password admin atau admin123.',
                        'Setelah berhasil login, masuk ke menu "Wireless".',
                        'Untuk mengganti nama WiFi, ubah isian pada kolom "SSID".',
                        'Untuk mengganti password, cari kolom "Password" dan masukkan password baru Anda.',
                        'Klik "Apply" untuk menyimpan perubahan. Modem akan restart secara otomatis.',
                      ],
                    ),

                    _buildSection(
                      'TOTOLINK N355RT',
                      [
                        'Hubungkan perangkat ke modem N355RT.',
                        'Buka browser dan masukkan alamat IP 192.168.0.1 atau 192.168.1.1.',
                        'Login dengan username admin dan password admin atau admin123.',
                        'Untuk mengganti nama WiFi, ubah isian pada kolom "SSID".',
                        'Untuk mengganti password, cari kolom "Password" dan masukkan password baru Anda.',
                        'Klik "Apply" untuk menerapkan perubahan.',
                      ],
                    ),

                    _buildSection(
                      'TP-LINK TL-WR820N',
                      [
                        'Hubungkan perangkat ke modem TL-WR820N.',
                        'Buka browser dan ketik tplinkwifi.net atau 192.168.0.1.',
                        'Jika ini pertama kali, Anda akan diminta membuat password login baru. Jika sudah pernah, masukkan password login yang telah Anda buat. Defaultnya adalah admin.',
                        'Setelah login, masuk ke menu "Wireless" atau "Nirkabel".',
                        'Ubah nama WiFi pada bagian "Nama Jaringan (SSID)".',
                        'Ubah password pada bagian "Password" atau "Kata Sandi".',
                        'Klik "Save" atau "Simpan". Modem akan restart.',
                      ],
                    ),

                    _buildSection(
                      'TP-LINK TL-WR840N',
                      [
                        'Hubungkan perangkat ke modem TL-WR840N.',
                        'Buka browser dan ketik tplinkwifi.net atau 192.168.0.1.',
                        'Login dengan username admin dan password admin atau admin123.',
                        'Masuk ke menu "Wireless", lalu pilih "Wireless Security".',
                        'Ubah password Anda di kolom "Wireless Password".',
                        'Klik "Save" untuk menyimpan perubahan.',
                        'Masuk ke menu "Wireless", lalu pilih "Basic Settings".',
                        'Untuk mengubah nama WiFi, ubah isian pada kolom "Wireless Network Name (SSID)".',
                        'klik "Save" untuk menyimpan perubahan.',
                      ],
                    ),

                    _buildSection(
                      'TENDA N301',
                      [
                        'Hubungkan perangkat ke modem TENDA N301.',
                        'Buka browser dan ketik 192.168.0.1.',
                        'Login dengan password admin atau admin123 (username biasanya tidak diminta).',
                        'Masuk ke menu "Wireless Settings".',
                        'Ubah nama WiFi di kolom "WiFi Name (SSID)".',
                        'Ubah password di kolom "WiFi Password".',
                        'Klik "OK". Modem akan menyimpan pengaturan.',
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Mengatasi Masalah Umum',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF110E1B)),
                    ),
                    const SizedBox(height: 16),

                    _buildTroubleshootingItem(
                      'Tidak bisa terhubung ke WiFi setelah ganti password',
                      'Ini adalah masalah paling umum. Perangkat Anda (HP/Laptop) masih menyimpan password lama. Solusinya:',
                      [
                        'Pada perangkat Anda, cari daftar jaringan WiFi yang tersedia.',
                        'Klik pada nama WiFi Anda, lalu pilih opsi "Lupakan Jaringan" (Forget Network).',
                        'Cari kembali jaringan WiFi Anda dan sambungkan lagi dengan memasukkan password yang baru.',
                      ],
                    ),

                    _buildTroubleshootingItem(
                      'Tidak bisa membuka halaman login modem',
                      null,
                      [
                        'Pastikan perangkat Anda sudah terhubung ke modem yang benar (baik via kabel atau WiFi).',
                        'Pastikan alamat IP yang Anda masukkan di browser sudah benar (misal: 192.168.0.1). Coba alamat alternatif seperti 192.168.1.1.',
                        'Coba gunakan browser yang berbeda atau clear cache browser Anda.',
                        'Jika semua cara gagal, langkah terakhir adalah melakukan reset pabrik pada modem, namun ini akan mengembalikan semua pengaturan ke awal, termasuk pengaturan dari ISP. Hubungi kami sebelum melakukan ini.',
                      ],
                    ),

                    _buildTroubleshootingItem(
                      'Koneksi internet lambat atau sering terputus',
                      null,
                      [
                        'Coba matikan modem selama 1-2 menit, lalu nyalakan kembali.',
                        'Pindahkan posisi modem ke tempat yang lebih terbuka dan minim halangan (seperti tembok tebal atau perabotan besar).',
                        'Jauhkan modem dari perangkat elektronik lain yang dapat menyebabkan interferensi, seperti microwave atau telepon nirkabel.',
                        'Jika masalah berlanjut, hubungi tim support kami untuk pengecekan lebih lanjut.',
                      ],
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

  Widget _buildSection(String title, List<String> steps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF110E1B),
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(color: Colors.grey[800], height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem(String title, String? description, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF110E1B),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey[800], height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(color: Colors.grey[800], height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
