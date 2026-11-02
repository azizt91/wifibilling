import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../core/services/thermal_printer_service.dart';
import '../../../../../core/widgets/printer_settings_modal.dart';
import '../../../../../data/providers/printer_provider.dart';

// App Settings Model
class AppSettingsModel {
  final String? id;
  final String appName;
  final String appShortName;
  final String appDescription;
  final String appTagline;
  final String? logoUrl;
  final String? faviconUrl;
  final String? icon192Url;
  final String? icon512Url;
  final String whatsappNumber;
  final String supportEmail;
  final String officeAddress;
  final String offlinePaymentName;
  final String offlinePaymentAddress;
  final String? qrisImageUrl;
  final bool showQris;
  final String themeColor;
  final String backgroundColor;

  AppSettingsModel({
    this.id,
    this.appName = 'WiFi Billing System',
    this.appShortName = 'WiFi Billing',
    this.appDescription = 'Sistem manajemen pelanggan ISP',
    this.appTagline = 'Kelola pelanggan dengan mudah',
    this.logoUrl,
    this.faviconUrl,
    this.icon192Url,
    this.icon512Url,
    this.whatsappNumber = '',
    this.supportEmail = '',
    this.officeAddress = '',
    this.offlinePaymentName = '',
    this.offlinePaymentAddress = '',
    this.qrisImageUrl,
    this.showQris = true,
    this.themeColor = '#683FE4',
    this.backgroundColor = '#F9F8FB',
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      id: json['id']?.toString(),
      appName: json['app_name']?.toString() ?? 'WiFi Billing System',
      appShortName: json['app_short_name']?.toString() ?? 'WiFi Billing',
      appDescription: json['app_description']?.toString() ?? '',
      appTagline: json['app_tagline']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      faviconUrl: json['favicon_url']?.toString(),
      icon192Url: json['icon_192_url']?.toString(),
      icon512Url: json['icon_512_url']?.toString(),
      whatsappNumber: json['whatsapp_number']?.toString() ?? '',
      supportEmail: json['support_email']?.toString() ?? '',
      officeAddress: json['office_address']?.toString() ?? '',
      offlinePaymentName: json['offline_payment_name']?.toString() ?? '',
      offlinePaymentAddress: json['offline_payment_address']?.toString() ?? '',
      qrisImageUrl: json['qris_image_url']?.toString(),
      showQris: json['show_qris'] == true,
      themeColor: json['theme_color']?.toString() ?? '#683FE4',
      backgroundColor: json['background_color']?.toString() ?? '#F9F8FB',
    );
  }

  Map<String, dynamic> toJson() => {
    'app_name': appName,
    'app_short_name': appShortName,
    'app_description': appDescription,
    'app_tagline': appTagline,
    'logo_url': logoUrl,
    'favicon_url': faviconUrl,
    'icon_192_url': icon192Url,
    'icon_512_url': icon512Url,
    'whatsapp_number': whatsappNumber,
    'support_email': supportEmail,
    'office_address': officeAddress,
    'offline_payment_name': offlinePaymentName,
    'offline_payment_address': offlinePaymentAddress,
    'qris_image_url': qrisImageUrl,
    'show_qris': showQris,
    'theme_color': themeColor,
    'background_color': backgroundColor,
  };
}

// WhatsApp Settings Model
class WhatsAppSettingsModel {
  final bool autoNotificationEnabled;
  final String fonnteToken;
  final String appUrl;
  final String templatePaymentFull;
  final String templatePaymentInstallment;
  final String templateCustomMessage;
  final String receiptFooter;

  WhatsAppSettingsModel({
    this.autoNotificationEnabled = false,
    this.fonnteToken = '',
    this.appUrl = '',
    this.templatePaymentFull = '',
    this.templatePaymentInstallment = '',
    this.templateCustomMessage = '',
    this.receiptFooter = '',
  });
}

// GenieACS Settings Model
class GenieACSSettingsModel {
  final bool enabled;
  final String url;
  final String username;
  final String password;

  GenieACSSettingsModel({
    this.enabled = false,
    this.url = '',
    this.username = '',
    this.password = '',
  });
}

// Providers
final appSettingsProvider = FutureProvider.autoDispose<AppSettingsModel>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('app_settings').select('*').maybeSingle();
  if (response == null) return AppSettingsModel();
  return AppSettingsModel.fromJson(response);
});

final whatsappSettingsProvider = FutureProvider.autoDispose<WhatsAppSettingsModel>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('whatsapp_settings').select('*');
  
  bool autoEnabled = false;
  String fonnteToken = '';
  String appUrl = '';
  String templateFull = '';
  String templateInstallment = '';
  String templateCustom = '';
  String receiptFooter = '';
  
  for (final row in response) {
    final key = row['setting_key']?.toString() ?? '';
    final value = row['setting_value']?.toString() ?? '';
    switch (key) {
      case 'auto_notification_enabled': autoEnabled = value == 'true'; break;
      case 'fonnte_token': fonnteToken = value; break;
      case 'app_url': appUrl = value; break;
      case 'template_payment_full': templateFull = value; break;
      case 'template_payment_installment': templateInstallment = value; break;
      case 'template_custom_message': templateCustom = value; break;
      case 'receipt_footer': receiptFooter = value; break;
    }
  }
  
  return WhatsAppSettingsModel(
    autoNotificationEnabled: autoEnabled,
    fonnteToken: fonnteToken,
    appUrl: appUrl,
    templatePaymentFull: templateFull,
    templatePaymentInstallment: templateInstallment,
    templateCustomMessage: templateCustom,
    receiptFooter: receiptFooter,
  );
});

final genieacsSettingsProvider = FutureProvider.autoDispose<GenieACSSettingsModel>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase.from('genieacs_settings').select('*');
    
    bool enabled = false;
    String url = '';
    String username = '';
    String password = '';
    
    for (final row in response) {
      final key = row['setting_key']?.toString() ?? '';
      final value = row['setting_value']?.toString() ?? '';
      switch (key) {
        case 'genieacs_enabled': enabled = value == 'true'; break;
        case 'genieacs_url': url = value; break;
        case 'genieacs_username': username = value; break;
        case 'genieacs_password': password = value; break;
      }
    }
    
    return GenieACSSettingsModel(enabled: enabled, url: url, username: username, password: password);
  } catch (e) {
    return GenieACSSettingsModel();
  }
});

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  // App Settings Controllers
  final _appNameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taglineController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _offlineNameController = TextEditingController();
  final _offlineAddressController = TextEditingController();
  
  // WhatsApp Settings Controllers
  final _fonnteTokenController = TextEditingController();
  final _appUrlController = TextEditingController();
  final _templateFullController = TextEditingController();
  final _templateInstallmentController = TextEditingController();
  final _templateCustomController = TextEditingController();
  final _receiptFooterController = TextEditingController();

  // GenieACS Settings Controllers
  final _genieacsUrlController = TextEditingController();
  final _genieacsUsernameController = TextEditingController();
  final _genieacsPasswordController = TextEditingController();
  
  // State
  bool _showQris = true;
  bool _autoNotification = false;
  bool _genieacsEnabled = false;
  bool _isSaving = false;
  bool _isLoaded = false;
  bool _showFonnteToken = false;
  bool _showGenieacsPassword = false;
  
  Color _themeColor = const Color(0xFF683FE4);
  Color _backgroundColor = const Color(0xFFF9F8FB);
  
  // Image URLs
  String? _logoUrl;
  String? _faviconUrl;
  String? _icon192Url;
  String? _icon512Url;
  String? _qrisImageUrl;
  String? _existingSettingsId;
  
  // Uploaded files
  File? _logoFile;
  File? _faviconFile;
  File? _icon192File;
  File? _icon512File;
  File? _qrisFile;

  @override
  void dispose() {
    _appNameController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _taglineController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _offlineNameController.dispose();
    _offlineAddressController.dispose();
    _fonnteTokenController.dispose();
    _appUrlController.dispose();
    _templateFullController.dispose();
    _templateInstallmentController.dispose();
    _templateCustomController.dispose();
    _receiptFooterController.dispose();
    _genieacsUrlController.dispose();
    _genieacsUsernameController.dispose();
    _genieacsPasswordController.dispose();
    super.dispose();
  }

  void _populateAppSettings(AppSettingsModel settings) {
    if (_isLoaded) return;
    _existingSettingsId = settings.id;
    _appNameController.text = settings.appName;
    _shortNameController.text = settings.appShortName;
    _descriptionController.text = settings.appDescription;
    _taglineController.text = settings.appTagline;
    _whatsappController.text = settings.whatsappNumber;
    _emailController.text = settings.supportEmail;
    _addressController.text = settings.officeAddress;
    _offlineNameController.text = settings.offlinePaymentName;
    _offlineAddressController.text = settings.offlinePaymentAddress;
    _showQris = settings.showQris;
    _logoUrl = settings.logoUrl;
    _faviconUrl = settings.faviconUrl;
    _icon192Url = settings.icon192Url;
    _icon512Url = settings.icon512Url;
    _qrisImageUrl = settings.qrisImageUrl;
    _themeColor = _hexToColor(settings.themeColor);
    _backgroundColor = _hexToColor(settings.backgroundColor);
    _isLoaded = true;
  }

  void _populateWhatsAppSettings(WhatsAppSettingsModel settings) {
    _autoNotification = settings.autoNotificationEnabled;
    _fonnteTokenController.text = settings.fonnteToken;
    _appUrlController.text = settings.appUrl;
    _templateFullController.text = settings.templatePaymentFull.isNotEmpty 
        ? settings.templatePaymentFull 
        : _getDefaultTemplatePaymentFull();
    _templateInstallmentController.text = settings.templatePaymentInstallment.isNotEmpty 
        ? settings.templatePaymentInstallment 
        : _getDefaultTemplateInstallment();
    _templateCustomController.text = settings.templateCustomMessage.isNotEmpty 
        ? settings.templateCustomMessage 
        : _getDefaultTemplateCustom();
    _receiptFooterController.text = settings.receiptFooter.isNotEmpty
        ? settings.receiptFooter
        : 'Terimakasih sudah bayar';
  }

  void _populateGenieACSSettings(GenieACSSettingsModel settings) {
    _genieacsEnabled = settings.enabled;
    _genieacsUrlController.text = settings.url;
    _genieacsUsernameController.text = settings.username;
    _genieacsPasswordController.text = settings.password;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  String _getDefaultTemplatePaymentFull() {
    return '''Konfirmasi Pembayaran LUNAS

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *TAGIHAN TELAH LUNAS!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Total Tagihan: *{total_tagihan}*
• Metode: {metode_pembayaran}
• Status: *LUNAS*

Terima kasih atas pembayaran Anda.

Login di:
*{app_url}*
*- Email:* {email_pelanggan}
*- Password:* password

_____________________________
*Pesan otomatis dari WiFi Billing System*''';
  }

  String _getDefaultTemplateInstallment() {
    return '''Konfirmasi Pembayaran Cicilan

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *Pembayaran cicilan diterima!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Jumlah Dibayar: *{jumlah_dibayar}*
• Metode: {metode_pembayaran}
• Sisa Tagihan: *{sisa_tagihan}*

Login di:
*{app_url}*
*- Email:* {email_pelanggan}
*- Password:* password

_____________________________
*Pesan otomatis dari WiFi Billing System*''';
  }

  String _getDefaultTemplateCustom() {
    return '''Pesan dari Admin

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

{pesan_custom}

_____________________________
*Pesan dari WiFi Billing System*''';
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(appSettingsProvider);
    final waSettings = ref.watch(whatsappSettingsProvider);
    final genieSettings = ref.watch(genieacsSettingsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: appSettings.when(
                data: (data) {
                  _populateAppSettings(data);
                  waSettings.whenData((wa) => _populateWhatsAppSettings(wa));
                  genieSettings.whenData((g) => _populateGenieACSSettings(g));
                  return _buildForm();
                },
                loading: () => _buildLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Color(0xFF110E1B)),
              ),
              const Expanded(
                child: Text('Pengaturan Aplikasi', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF110E1B))),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Printer Thermal Bluetooth Section
          _buildSection('Printer Thermal Bluetooth', Icons.print, [
            Consumer(
              builder: (context, ref, _) {
                final printer = ref.watch(printerProvider);
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: printer.isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: printer.isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            printer.isConnected ? Icons.check_circle : Icons.bluetooth_disabled,
                            color: printer.isConnected ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  printer.isConnected
                                      ? 'Printer Terhubung (${printer.paperSize == ThermalPaperSize.mm80 ? "80mm" : "58mm"})'
                                      : 'Printer Belum Terhubung',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: printer.isConnected ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                  ),
                                ),
                                Text(
                                  printer.isConnected
                                      ? '${printer.connectedName} (${printer.connectedMac})'
                                      : 'Buka pengaturan untuk menghubungkan printer kasir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: printer.isConnected ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => PrinterSettingsModal.show(context, storeName: _appNameController.text),
                        icon: const Icon(Icons.settings_bluetooth, size: 18),
                        label: const Text('Buka Pengaturan & Scan Printer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF683FE4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Pengaturan Struk Kasir Section
          _buildSection('Pengaturan Struk Kasir (Printer Thermal)', Icons.receipt_long, [
            _buildTextField(
              'Catatan / Pesan Footer Struk',
              _receiptFooterController,
              'Contoh: Terimakasih sudah bayar',
              maxLines: 3,
              hint: 'Pesan ini akan dicetak di bagian paling bawah struk thermal (kasir/Bluetooth) pada aplikasi web dan mobile.',
            ),
          ]),
          const SizedBox(height: 16),
          
          // WhatsApp Notification
          _buildSection('Notifikasi WhatsApp', Icons.chat_outlined, [
            _buildToggle('Notifikasi Otomatis', 'Kirim WhatsApp otomatis saat pembayaran diterima', _autoNotification, (v) => setState(() => _autoNotification = v)),
            const SizedBox(height: 12),
            _buildPasswordField('Fonnte API Token', _fonnteTokenController, 'Masukkan token Fonnte', _showFonnteToken, () => setState(() => _showFonnteToken = !_showFonnteToken), hint: 'Token API dari fonnte.com'),
            _buildTextField('URL Aplikasi', _appUrlController, 'https://oawsmjpibfwpiaebvhot.supabase.co', hint: 'URL untuk login pelanggan di pesan WhatsApp'),
            _buildTextField('Template Pembayaran Lunas', _templateFullController, 'Template pesan...', maxLines: 8, hint: 'Variabel: {nama_pelanggan}, {idpl}, {periode}, {total_tagihan}, {metode_pembayaran}, {app_url}, {email_pelanggan}'),
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesan ini akan terkirim otomatis ke WhatsApp pelanggan saat status tagihan dicatat Lunas, asalkan tombol "Notifikasi Otomatis" aktif dan "Fonnte API Token" telah diisi.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            _buildTextField('Template Pembayaran Cicilan', _templateInstallmentController, 'Template pesan...', maxLines: 8, hint: 'Variabel: {nama_pelanggan}, {idpl}, {periode}, {jumlah_dibayar}, {sisa_tagihan}, {metode_pembayaran}, {app_url}, {email_pelanggan}'),
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesan ini akan terkirim otomatis ke WhatsApp pelanggan saat pembayaran Cicilan dicatat, asalkan tombol "Notifikasi Otomatis" aktif dan "Fonnte API Token" telah diisi.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            _buildTextField('Template Pesan Manual', _templateCustomController, 'Template pesan...', maxLines: 6, hint: 'Variabel: {nama_pelanggan}, {idpl}, {pesan_custom}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetWhatsAppTemplates,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Reset ke Template Default'),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // GenieACS Configuration
          _buildSection('Konfigurasi GenieACS', Icons.router_outlined, [
            _buildToggle('Aktifkan GenieACS', 'Izinkan pelanggan mengganti SSID & Password WiFi', _genieacsEnabled, (v) => setState(() => _genieacsEnabled = v)),
            const SizedBox(height: 12),
            _buildTextField('URL GenieACS', _genieacsUrlController, 'http://192.168.1.10:7547', hint: 'URL server GenieACS Anda'),
            _buildTextField('Username (Opsional)', _genieacsUsernameController, 'Kosongkan jika tidak ada autentikasi'),
            _buildPasswordField('Password (Opsional)', _genieacsPasswordController, 'Kosongkan jika tidak ada autentikasi', _showGenieacsPassword, () => setState(() => _showGenieacsPassword = !_showGenieacsPassword)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Jika GenieACS diaktifkan, pelanggan dapat mengganti SSID dan Password WiFi mereka sendiri.', style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAllSettings,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('SIMPAN SEMUA PENGATURAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF110E1B)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF110E1B))),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String placeholder, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
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

  Widget _buildPasswordField(String label, TextEditingController controller, String placeholder, bool showPassword, VoidCallback onToggle, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: !showPassword,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D0E7))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: IconButton(icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: onToggle),
            ),
          ),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF683FE4)),
        ],
      ),
    );
  }

  Widget _buildColorPicker(String label, Color color, ValueChanged<Color> onChanged, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showColorPickerDialog(color, onChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD6D0E7)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[300]!))),
                  const SizedBox(width: 12),
                  Text(_colorToHex(color), style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
                  const Spacer(),
                  Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
        ],
      ),
    );
  }

  void _showColorPickerDialog(Color currentColor, ValueChanged<Color> onChanged) {
    Color pickedColor = currentColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (c) => pickedColor = c,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              onChanged(pickedColor);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4)),
            child: const Text('Pilih', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploader(String label, String? imageUrl, File? localFile, String hint, VoidCallback onTap, {bool small = false}) {
    final size = small ? 60.0 : 80.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF110E1B))),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: localFile != null
                    ? Image.file(localFile, fit: BoxFit.contain)
                    : (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.image, size: 32, color: Colors.grey[400]))
                        : Icon(Icons.image, size: 32, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF683FE4)),
                      child: Text(small ? 'Upload' : 'Upload $label'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null) return;
    
    final file = File(picked.path);
    setState(() {
      switch (type) {
        case 'logo': _logoFile = file; break;
        case 'favicon': _faviconFile = file; break;
        case 'icon192': _icon192File = file; break;
        case 'icon512': _icon512File = file; break;
      }
    });
  }

  Future<String?> _uploadImage(File file, String folder) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final ext = file.path.split('.').last;
      final fileName = '$folder-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '$folder/$fileName';
      
      await supabase.storage.from('avatars').upload(filePath, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
      final url = supabase.storage.from('avatars').getPublicUrl(filePath);
      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  void _resetWhatsAppTemplates() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Template?'),
        content: const Text('Reset semua template WhatsApp ke default?\n\nPerubahan tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _templateFullController.text = _getDefaultTemplatePaymentFull();
                _templateInstallmentController.text = _getDefaultTemplateInstallment();
                _templateCustomController.text = _getDefaultTemplateCustom();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template berhasil direset ke default')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF683FE4)),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(6, (_) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 180,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          )),
        ),
      ),
    );
  }

  Future<void> _saveAllSettings() async {
    if (_appNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama aplikasi tidak boleh kosong')));
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // Upload images if changed
      String? logoUrl = _logoUrl;
      String? faviconUrl = _faviconUrl;
      String? icon192Url = _icon192Url;
      String? icon512Url = _icon512Url;
      String? qrisUrl = _qrisImageUrl;
      
      if (_logoFile != null) logoUrl = await _uploadImage(_logoFile!, 'logos');
      if (_faviconFile != null) faviconUrl = await _uploadImage(_faviconFile!, 'favicons');
      if (_icon192File != null) icon192Url = await _uploadImage(_icon192File!, 'icons');
      if (_icon512File != null) icon512Url = await _uploadImage(_icon512File!, 'icons');

      // Save App Settings
      final appSettings = {
        'app_name': _appNameController.text.trim(),
        'app_short_name': _shortNameController.text.trim(),
        'app_description': _descriptionController.text.trim(),
        'app_tagline': _taglineController.text.trim(),
        'logo_url': logoUrl,
        'favicon_url': faviconUrl,
        'icon_192_url': icon192Url,
        'icon_512_url': icon512Url,
        'whatsapp_number': _whatsappController.text.trim(),
        'support_email': _emailController.text.trim(),
        'office_address': _addressController.text.trim(),
        'offline_payment_name': _offlineNameController.text.trim(),
        'offline_payment_address': _offlineAddressController.text.trim(),
        'qris_image_url': qrisUrl,
        'show_qris': _showQris,
        'theme_color': _colorToHex(_themeColor),
        'background_color': _colorToHex(_backgroundColor),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_existingSettingsId != null) {
        appSettings['id'] = _existingSettingsId!;
      }

      await supabase.from('app_settings').upsert(appSettings);

      // Save WhatsApp Settings & Receipt Footer
      final waSettings = [
        {'setting_key': 'auto_notification_enabled', 'setting_value': _autoNotification ? 'true' : 'false'},
        {'setting_key': 'fonnte_token', 'setting_value': _fonnteTokenController.text.trim()},
        {'setting_key': 'app_url', 'setting_value': _appUrlController.text.trim()},
        {'setting_key': 'template_payment_full', 'setting_value': _templateFullController.text},
        {'setting_key': 'template_payment_installment', 'setting_value': _templateInstallmentController.text},
        {'setting_key': 'template_custom_message', 'setting_value': _templateCustomController.text},
        {'setting_key': 'receipt_footer', 'setting_value': _receiptFooterController.text.trim()},
      ];

      for (final setting in waSettings) {
        final existing = await supabase.from('whatsapp_settings').select('id').eq('setting_key', setting['setting_key']!).maybeSingle();
        if (existing != null) {
          await supabase.from('whatsapp_settings').update({
            'setting_value': setting['setting_value'],
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('setting_key', setting['setting_key']!);
        } else {
          await supabase.from('whatsapp_settings').insert({
            'setting_key': setting['setting_key'],
            'setting_value': setting['setting_value'],
            'is_enabled': true,
          });
        }
      }

      // Sinkronkan footer struk ke thermal printer lokal
      final footerText = _receiptFooterController.text.trim();
      if (footerText.isNotEmpty) {
        await ThermalPrinterService().setReceiptFooter(footerText);
      }

      // Save GenieACS Settings
      final genieSettings = [
        {'setting_key': 'genieacs_enabled', 'setting_value': _genieacsEnabled ? 'true' : 'false'},
        {'setting_key': 'genieacs_url', 'setting_value': _genieacsUrlController.text.trim()},
        {'setting_key': 'genieacs_username', 'setting_value': _genieacsUsernameController.text.trim()},
        {'setting_key': 'genieacs_password', 'setting_value': _genieacsPasswordController.text.trim()},
      ];

      for (final setting in genieSettings) {
        try {
          final existing = await supabase.from('genieacs_settings').select('id').eq('setting_key', setting['setting_key']!).maybeSingle();
          if (existing != null) {
            await supabase.from('genieacs_settings').update({
              'setting_value': setting['setting_value'],
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('setting_key', setting['setting_key']!);
          } else {
            await supabase.from('genieacs_settings').insert({
              'setting_key': setting['setting_key'],
              'setting_value': setting['setting_value'],
              'is_enabled': true,
            });
          }
        } catch (e) {
          debugPrint('GenieACS setting error: $e');
        }
      }

      // Invalidate providers to refresh data
      ref.invalidate(appSettingsProvider);
      ref.invalidate(whatsappSettingsProvider);
      ref.invalidate(genieacsSettingsProvider);

      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('✅ Semua pengaturan berhasil disimpan!'),
        backgroundColor: Color(0xFF22C55E),
      ));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('❌ Gagal menyimpan: $e'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
