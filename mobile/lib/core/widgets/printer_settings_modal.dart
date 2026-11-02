import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/printer_provider.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_colors.dart';

class PrinterSettingsModal extends ConsumerStatefulWidget {
  final String? storeName;

  const PrinterSettingsModal({super.key, this.storeName});

  static Future<void> show(BuildContext context, {String? storeName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrinterSettingsModal(storeName: storeName),
    );
  }

  @override
  ConsumerState<PrinterSettingsModal> createState() => _PrinterSettingsModalState();
}

class _PrinterSettingsModalState extends ConsumerState<PrinterSettingsModal> {
  late final TextEditingController _footerController;
  bool _isSavingFooter = false;

  @override
  void initState() {
    super.initState();
    final currentFooter = ThermalPrinterService().receiptFooter ?? '';
    _footerController = TextEditingController(text: currentFooter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerProvider.notifier).scanDevices();
      _loadRemoteFooter();
    });
  }

  Future<void> _loadRemoteFooter() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('whatsapp_settings')
          .select('setting_value')
          .eq('setting_key', 'receipt_footer')
          .maybeSingle();
      if (res != null && res['setting_value'] != null) {
        final val = res['setting_value'].toString().trim();
        if (val.isNotEmpty && mounted) {
          _footerController.text = val;
          await ThermalPrinterService().setReceiptFooter(val);
        }
      }
    } catch (e) {
      debugPrint('Error load remote footer: $e');
    }
  }

  Future<void> _saveFooter() async {
    setState(() => _isSavingFooter = true);
    final text = _footerController.text.trim();
    try {
      await ThermalPrinterService().setReceiptFooter(text);
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('whatsapp_settings').upsert({
        'setting_key': 'receipt_footer',
        'setting_value': text,
        'is_enabled': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id, setting_key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesan footer struk berhasil disimpan!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan footer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingFooter = false);
    }
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);
    final printerNotifier = ref.read(printerProvider.notifier);

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafe = mediaQuery.padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: bottomInset + bottomSafe + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
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
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Printer Thermal Bluetooth',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Pengaturan koneksi cetak struk kasir',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status Koneksi Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: printerState.isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: printerState.isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  printerState.isConnected ? Icons.check_circle : Icons.bluetooth_disabled,
                  color: printerState.isConnected ? Colors.green : Colors.red,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerState.isConnected ? 'Printer Terhubung' : 'Printer Terputus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: printerState.isConnected ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        printerState.isConnected
                            ? '${printerState.connectedName ?? "Device"} (${printerState.connectedMac})'
                            : 'Pilih perangkat printer di bawah untuk menghubungkan',
                        style: TextStyle(
                          fontSize: 11,
                          color: printerState.isConnected ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (printerState.isConnected)
                  TextButton(
                    onPressed: () => printerNotifier.disconnect(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Putus'),
                  ),
              ],
            ),
          ),

          if (printerState.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      printerState.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Pilihan Ukuran Kertas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ukuran Kertas Thermal:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('58 mm'),
                    selected: printerState.paperSize == ThermalPaperSize.mm58,
                    onSelected: (val) {
                      if (val) printerNotifier.setPaperSize(ThermalPaperSize.mm58);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: printerState.paperSize == ThermalPaperSize.mm58 ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('80 mm'),
                    selected: printerState.paperSize == ThermalPaperSize.mm80,
                    onSelected: (val) {
                      if (val) printerNotifier.setPaperSize(ThermalPaperSize.mm80);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: printerState.paperSize == ThermalPaperSize.mm80 ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24),

          // Header List Perangkat & Tombol Scan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Printer Paired',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              TextButton.icon(
                onPressed: printerState.isScanning ? null : () => printerNotifier.scanDevices(),
                icon: printerState.isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(printerState.isScanning ? 'Memindai...' : 'Pindai Perangkat'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),

          // Device List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: printerState.availableDevices.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print_disabled_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada printer Bluetooth terdeteksi.\nPastikan printer dinyalakan dan sudah di-pair di menu Bluetooth HP.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: printerState.availableDevices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final device = printerState.availableDevices[idx];
                      final isCurrent = printerState.isConnected && printerState.connectedMac == device.macAdress;

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isCurrent ? Colors.green.shade100 : Colors.grey.shade200,
                          child: Icon(
                            Icons.print,
                            size: 18,
                            color: isCurrent ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                        title: Text(
                          device.name.isEmpty ? 'Unknown Printer' : device.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          device.macAdress,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: isCurrent
                            ? const Chip(
                                label: Text('Aktif', style: TextStyle(fontSize: 10, color: Colors.green)),
                                backgroundColor: Color(0xFFDCFCE7),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              )
                            : ElevatedButton(
                                onPressed: printerState.isConnecting
                                    ? null
                                    : () => printerNotifier.connect(device.macAdress, device.name),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: printerState.isConnecting
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Konek', style: TextStyle(fontSize: 12)),
                              ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // Pengaturan Pesan Footer Struk Dinamis
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Pesan Footer Struk',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pesan khusus yang dicetak di bagian paling bawah struk kasir.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _footerController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Jika ada gangguan internet hubungi CS: 0812-XXXX-XXXX. Simpan struk ini sebagai bukti sah.',
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingFooter ? null : _saveFooter,
                    icon: _isSavingFooter
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Simpan Footer', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tombol Test Print
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: !printerState.isConnected
                  ? null
                  : () async {
                      try {
                        final ok = await printerNotifier.testPrint(storeName: widget.storeName);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Berhasil mengirim perintah cetak tes!' : 'Gagal mencetak struk tes.'),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text(
                'Cetak Struk Uji Coba (Test Print)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

