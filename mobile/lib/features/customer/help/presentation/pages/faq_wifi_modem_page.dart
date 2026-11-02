import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FaqWifiModemPage extends StatelessWidget {
  const FaqWifiModemPage({super.key});

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
                      'FAQ Wi-Fi Modem',
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFaqItem(
                        'Bagaimana cara merestart modem Wi-Fi saya?',
                        'Untuk merestart modem Wi-Fi Anda, cabut kabel daya modem dari stopkontak, tunggu sekitar 10-15 detik, lalu colokkan kembali. Tunggu beberapa menit hingga semua lampu indikator modem menyala stabil.',
                      ),
                      _buildDivider(),
                      _buildFaqItem(
                        'Apa yang harus saya lakukan jika Wi-Fi saya lambat?',
                        'Jika Wi-Fi Anda lambat, coba beberapa langkah berikut:\n\n'
                        '• Restart modem dan router Anda.\n'
                        '• Pastikan modem diletakkan di lokasi sentral dan tidak terhalang.\n'
                        '• Kurangi jumlah perangkat yang terhubung secara bersamaan.\n'
                        '• Periksa apakah ada pembaruan firmware untuk modem Anda.\n'
                        '• Hubungi penyedia layanan internet Anda jika masalah berlanjut.',
                      ),
                      _buildDivider(),
                      _buildFaqItem(
                        'Bagaimana cara mengubah nama dan kata sandi Wi-Fi saya?',
                        'Biasanya, Anda dapat mengubah nama (SSID) dan kata sandi Wi-Fi melalui antarmuka web modem/router Anda. Buka browser, ketik alamat IP default modem (misalnya, 192.168.1.1 atau 192.168.0.1), lalu masuk dengan nama pengguna dan kata sandi admin. Cari bagian pengaturan Wi-Fi atau Nirkabel untuk melakukan perubahan.',
                      ),
                      _buildDivider(),
                      _buildFaqItem(
                        'Mengapa lampu indikator modem saya berkedip merah?',
                        'Lampu indikator modem yang berkedip merah seringkali menandakan masalah koneksi internet. Ini bisa berarti:\n\n'
                        '• Tidak ada sinyal dari penyedia layanan internet.\n'
                        '• Kabel longgar atau rusak.\n'
                        '• Masalah pada modem itu sendiri.\n\n'
                        'Coba restart modem Anda. Jika masalah berlanjut, periksa semua kabel dan hubungi dukungan teknis penyedia layanan internet Anda.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF110E1B),
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedAlignment: Alignment.centerLeft,
      children: [
        Text(
          answer,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[200]);
  }
}
