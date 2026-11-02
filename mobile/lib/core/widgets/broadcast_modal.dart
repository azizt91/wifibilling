import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/whatsapp_notification_service.dart';
import '../theme/app_colors.dart';

class BroadcastModal extends ConsumerStatefulWidget {
  final List<dynamic> selectedInvoices;
  final VoidCallback onCompleted;

  const BroadcastModal({
    super.key,
    required this.selectedInvoices,
    required this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required List<dynamic> selectedInvoices,
    required VoidCallback onCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BroadcastModal(
        selectedInvoices: selectedInvoices,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<BroadcastModal> createState() => _BroadcastModalState();
}

class _BroadcastModalState extends ConsumerState<BroadcastModal> {
  final _templateController = TextEditingController();
  final _limitController = TextEditingController();
  final _customDelayController = TextEditingController(text: '7');

  String _delayMode = 'safe'; // 'safe', 'supersafe', 'custom'
  bool _isLoadingTemplate = true;
  bool _isSending = false;
  bool _isCancelled = false;

  int _currentIndex = 0;
  int _totalToSend = 0;
  int _countdownSeconds = 0;
  String _currentCustomerName = '';
  int _sentCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _limitController.text = min(20, widget.selectedInvoices.length).toString();
    _loadTemplate();
  }

  @override
  void dispose() {
    _templateController.dispose();
    _limitController.dispose();
    _customDelayController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('whatsapp_settings')
          .select('setting_value')
          .eq('setting_key', 'template_custom_message')
          .maybeSingle();

      if (res != null && res['setting_value'] != null && res['setting_value'].toString().isNotEmpty) {
        _templateController.text = res['setting_value'];
      } else {
        _templateController.text = _getDefaultTemplate();
      }
    } catch (_) {
      _templateController.text = _getDefaultTemplate();
    } finally {
      if (mounted) setState(() => _isLoadingTemplate = false);
    }
  }

  String _getDefaultTemplate() {
    return '''Informasi Tagihan WiFi Anda

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

Informasi tagihan Bapak/Ibu bulan ini adalah:
Jumlah Tagihan: {total_tagihan}
Periode Tagihan: {periode}

Terima kasih atas kepercayaan Anda menggunakan layanan kami.
_____________________________
*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.*''';
  }

  int _calculateDelay() {
    final rand = Random();
    if (_delayMode == 'safe') {
      return 5 + rand.nextInt(6); // 5 - 10 detik
    } else if (_delayMode == 'supersafe') {
      return 10 + rand.nextInt(11); // 10 - 20 detik
    } else {
      return int.tryParse(_customDelayController.text) ?? 7;
    }
  }

  Future<void> _startBroadcast() async {
    final template = _templateController.text.trim();
    if (template.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template pesan tidak boleh kosong')),
      );
      return;
    }

    final limit = int.tryParse(_limitController.text) ?? widget.selectedInvoices.length;
    final invoicesToProcess = widget.selectedInvoices.take(limit).toList();

    if (invoicesToProcess.isEmpty) return;

    setState(() {
      _isSending = true;
      _isCancelled = false;
      _totalToSend = invoicesToProcess.length;
      _currentIndex = 0;
      _sentCount = 0;
      _failedCount = 0;
    });

    final supabase = ref.read(supabaseClientProvider);
    final waService = WhatsAppNotificationService(supabase);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    for (int i = 0; i < invoicesToProcess.length; i++) {
      if (_isCancelled || !mounted) break;

      final inv = invoicesToProcess[i];
      final customerName = inv.customerName;
      final phone = inv.customerWhatsapp;

      setState(() {
        _currentIndex = i + 1;
        _currentCustomerName = customerName;
      });

      if (phone == null || phone.toString().trim().length < 9) {
        _failedCount++;
        continue;
      }

      // Format template variables
      String message = template
          .replaceAll('{nama_pelanggan}', customerName)
          .replaceAll('{idpl}', inv.customerIdpl ?? '-')
          .replaceAll('{periode}', inv.invoicePeriod)
          .replaceAll('{total_tagihan}', currencyFormat.format(inv.totalDue));

      try {
        final result = await waService.sendMessage(phoneNumber: phone.toString(), message: message);

        if (result['success'] == true) {
          _sentCount++;
          // Update broadcast count in database
          try {
            await supabase.from('invoices').update({
              'broadcast_count': (inv.broadcastCount + 1),
              'last_broadcast_at': DateTime.now().toIso8601String(),
            }).eq('id', inv.id);
          } catch (_) {}
        } else {
          _failedCount++;
        }
      } catch (_) {
        _failedCount++;
      }

      // Delay acak anti-banned jika bukan nomor terakhir
      if (i < invoicesToProcess.length - 1 && !_isCancelled && mounted) {
        final delaySec = _calculateDelay();
        for (int c = delaySec; c > 0; c--) {
          if (_isCancelled || !mounted) break;
          setState(() => _countdownSeconds = c);
          await Future.delayed(const Duration(seconds: 1));
        }
        if (mounted) setState(() => _countdownSeconds = 0);
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
      widget.onCompleted();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(_isCancelled ? Icons.warning_amber : Icons.check_circle, color: _isCancelled ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(_isCancelled ? 'Broadcast Dibatalkan' : 'Broadcast Selesai', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Laporan Pengiriman:\n• Terkirim Sukses: $_sentCount nomor\n• Gagal / Dilewati: $_failedCount nomor',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK Selesai'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSending) {
      return _buildSendingProgress();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chat, color: Color(0xFF22C55E), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Broadcast WhatsApp Tagihan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('${widget.selectedInvoices.length} pelanggan terpilih', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),

            const SizedBox(height: 16),

            // Pilihan Anti-Banned Delay
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F8FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF22C55E), size: 18),
                      SizedBox(width: 6),
                      Text('Anti-Banned Smart Delay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _delayMode,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'safe', child: Text('Aman (Jeda Acak 5 - 10 Detik)')),
                      DropdownMenuItem(value: 'supersafe', child: Text('Super Aman (Jeda Acak 10 - 20 Detik)')),
                      DropdownMenuItem(value: 'custom', child: Text('Kustom (Detik Tetap)')),
                    ],
                    onChanged: (val) => setState(() => _delayMode = val ?? 'safe'),
                  ),
                  if (_delayMode == 'custom') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customDelayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jeda per pesan (detik)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Limit Batch
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Batas Kirim (Batch Ini)',
                      filled: true,
                      fillColor: const Color(0xFFF9F8FB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _limitController.text = widget.selectedInvoices.length.toString());
                  },
                  child: const Text('Lepas Batas', style: TextStyle(color: Color(0xFF683FE4), fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Template Editor
            const Text('Template Pesan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            if (_isLoadingTemplate)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else
              TextFormField(
                controller: _templateController,
                maxLines: 6,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9F8FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  hintText: 'Tulis template pesan di sini...',
                ),
                style: const TextStyle(fontSize: 12),
              ),

            const SizedBox(height: 8),
            const Text(
              'Variabel otomatis: {nama_pelanggan}, {idpl}, {total_tagihan}, {periode}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Tombol Kirim
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startBroadcast,
                icon: const Icon(Icons.send, size: 18),
                label: Text('Kirim Pesan ke ${_limitController.text} Pelanggan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingProgress() {
    final progress = _totalToSend > 0 ? _currentIndex / _totalToSend : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Color(0xFF22C55E), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Memproses Broadcast WhatsApp...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '[$_currentIndex / $_totalToSend] Mengirim ke $_currentCustomerName...',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          if (_countdownSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text('Jeda acak anti-banned: $_countdownSeconds detik', style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isCancelled = true);
            },
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            label: const Text('Hentikan Pengiriman', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
