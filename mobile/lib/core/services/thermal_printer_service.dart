import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThermalPaperSize { mm58, mm80 }

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  static const MethodChannel _permissionChannel = MethodChannel('com.wifibilling.app/bluetooth_permission');

  static const String _prefKeyPrinterMac = 'thermal_printer_mac';
  static const String _prefKeyPrinterName = 'thermal_printer_name';
  static const String _prefKeyPaperSize = 'thermal_printer_paper_size';
  static const String _prefKeyReceiptFooter = 'thermal_printer_receipt_footer';

  ThermalPaperSize _paperSize = ThermalPaperSize.mm58;
  ThermalPaperSize get paperSize => _paperSize;

  String? _connectedMac;
  String? _connectedName;
  String? _receiptFooter;
  String? get connectedName => _connectedName;
  String? get connectedMac => _connectedMac;
  String? get receiptFooter => _receiptFooter;

  /// Inisialisasi preferensi printer tersimpan
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _connectedMac = prefs.getString(_prefKeyPrinterMac);
      _connectedName = prefs.getString(_prefKeyPrinterName);
      _receiptFooter = prefs.getString(_prefKeyReceiptFooter);
      final sizeStr = prefs.getString(_prefKeyPaperSize);
      if (sizeStr == 'mm80') {
        _paperSize = ThermalPaperSize.mm80;
      } else {
        _paperSize = ThermalPaperSize.mm58;
      }
    } catch (e) {
      debugPrint('Error init ThermalPrinterService: $e');
    }
  }

  /// Cek & Minta Izin Bluetooth (Nearby Devices) di Android 12+ / Location di Android <12
  Future<bool> checkAndRequestBluetoothPermission() async {
    try {
      final result = await _permissionChannel.invokeMethod<bool>('checkAndRequestBluetoothPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Error request bluetooth permission: $e');
      return false;
    }
  }

  /// Cek apakah Bluetooth HP aktif
  Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('Error check bluetooth: $e');
      return false;
    }
  }

  /// Ambil daftar perangkat Bluetooth yang sudah dipasangkan (paired)
  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      // 1. Pastikan izin Bluetooth diberikan terlebih dahulu
      final hasPermission = await checkAndRequestBluetoothPermission();
      if (!hasPermission) {
        debugPrint('Bluetooth permission not granted by user');
        return [];
      }

      // 2. Ambil paired devices dengan proteksi timeout (anti-hang)
      final devices = await PrintBluetoothThermal.pairedBluetooths.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('PrintBluetoothThermal.pairedBluetooths timed out');
          return <BluetoothInfo>[];
        },
      );
      return devices;
    } catch (e) {
      debugPrint('Error get paired devices: $e');
      return [];
    }
  }

  /// Cek apakah saat ini terkoneksi ke printer
  Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      debugPrint('Error checking connection: $e');
      return false;
    }
  }

  /// Hubungkan ke printer berdasarkan MAC Address
  Future<bool> connect(String macAddress, {String? deviceName}) async {
    try {
      // Putuskan koneksi sebelumnya jika ada
      final alreadyConnected = await isConnected();
      if (alreadyConnected && _connectedMac == macAddress) {
        return true;
      } else if (alreadyConnected) {
        await disconnect();
      }

      final result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress).timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('PrintBluetoothThermal.connect timed out');
          return false;
        },
      );
      if (result) {
        _connectedMac = macAddress;
        _connectedName = deviceName ?? macAddress;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyPrinterMac, macAddress);
        if (deviceName != null) {
          await prefs.setString(_prefKeyPrinterName, deviceName);
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  /// Putuskan koneksi printer
  Future<bool> disconnect() async {
    try {
      final result = await PrintBluetoothThermal.disconnect;
      if (result) {
        _connectedMac = null;
        _connectedName = null;
      }
      return result;
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
      return false;
    }
  }

  /// Auto-connect ke printer terakhir yang pernah terhubung
  Future<bool> autoConnect() async {
    if (_connectedMac == null) return false;
    final connected = await isConnected();
    if (connected) return true;
    return await connect(_connectedMac!, deviceName: _connectedName);
  }

  /// Set ukuran kertas (58mm atau 80mm)
  Future<void> setPaperSize(ThermalPaperSize size) async {
    _paperSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPaperSize, size == ThermalPaperSize.mm80 ? 'mm80' : 'mm58');
  }

  /// Simpan catatan/pesan footer struk
  Future<void> setReceiptFooter(String footer) async {
    _receiptFooter = footer;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyReceiptFooter, footer);
  }

  /// Cetak Struk Uji Coba (Test Print)
  Future<bool> printTestReceipt({String? storeName}) async {
    final connected = await isConnected();
    if (!connected) {
      final autoReconnected = await autoConnect();
      if (!autoReconnected) {
        throw Exception('Printer Bluetooth belum terhubung. Silakan hubungkan printer terlebih dahulu.');
      }
    }

    final profile = await CapabilityProfile.load();
    final is80mm = _paperSize == ThermalPaperSize.mm80;
    final generator = Generator(
      is80mm ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    final displayName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim().toUpperCase()
        : 'WIFI BILLING SYSTEM';

    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      displayName,
      styles: PosStyles(
        align: PosAlign.center,
        height: is80mm
            ? (displayName.length <= 20 ? PosTextSize.size2 : PosTextSize.size1)
            : (displayName.length <= 16 ? PosTextSize.size2 : PosTextSize.size1),
        width: is80mm
            ? (displayName.length <= 20 ? PosTextSize.size2 : PosTextSize.size1)
            : PosTextSize.size1,
        bold: true,
      ),
    );
    bytes += generator.text(
      'Uji Coba Cetak Printer Thermal',
      styles: const PosStyles(align: PosAlign.center, bold: false),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Tanggal: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.text(
      'Ukuran Kertas: ${_paperSize == ThermalPaperSize.mm80 ? "80 mm" : "58 mm"}',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.text(
      'Status: BERHASIL KONEK OK!',
      styles: const PosStyles(align: PosAlign.left, bold: true),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Printer siap digunakan untuk mencetak struk tagihan pelanggan.',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Cetak Struk Pembayaran Tagihan
  Future<bool> printInvoiceReceipt({
    required String invoiceId,
    required String customerName,
    required String? idpl,
    required String period,
    required double totalAmount,
    required double paidAmount,
    required String status,
    String? paymentMethod,
    DateTime? paidDate,
    String? ispName,
    String? ispPhone,
    String? ispAddress,
    String? adminName,
    String? receiptFooter,
  }) async {
    final connected = await isConnected();
    if (!connected) {
      final autoReconnected = await autoConnect();
      if (!autoReconnected) {
        throw Exception('Printer belum terhubung. Hubungkan printer di menu Printer.');
      }
    }

    final profile = await CapabilityProfile.load();
    final is80mm = _paperSize == ThermalPaperSize.mm80;
    final generator = Generator(is80mm ? PaperSize.mm80 : PaperSize.mm58, profile);

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    List<int> bytes = [];
    bytes += generator.reset();

    // 1. Header ISP / Tenant
    final displayName = (ispName != null && ispName.trim().isNotEmpty)
        ? ispName.trim().toUpperCase()
        : 'WIFI BILLING SYSTEM';

    // Sesuaikan font agar proporsional dan tidak terpotong (terutama di 58mm dengan 32 kolom)
    bytes += generator.text(
      displayName,
      styles: PosStyles(
        align: PosAlign.center,
        height: is80mm
            ? (displayName.length <= 20 ? PosTextSize.size2 : PosTextSize.size1)
            : (displayName.length <= 16 ? PosTextSize.size2 : PosTextSize.size1),
        width: is80mm
            ? (displayName.length <= 20 ? PosTextSize.size2 : PosTextSize.size1)
            : PosTextSize.size1,
        bold: true,
      ),
    );

    if (ispAddress != null && ispAddress.trim().isNotEmpty) {
      bytes += generator.text(
        ispAddress.trim(),
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (ispPhone != null && ispPhone.trim().isNotEmpty) {
      bytes += generator.text(
        'WA/Telp: ${ispPhone.trim()}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr(ch: '=');

    // 2. Judul Struk & Info Transaksi
    bytes += generator.text(
      'STRUK PEMBAYARAN TAGIHAN',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    final shortInvId = invoiceId.length > 8 ? invoiceId.substring(0, 8).toUpperCase() : invoiceId.toUpperCase();
    bytes += generator.text(
      'No. Ref: INV-$shortInvId',
      styles: const PosStyles(align: PosAlign.center),
    );
    final dateDisplay = DateFormat('dd/MM/yyyy HH:mm').format(paidDate ?? DateTime.now());
    bytes += generator.text(
      'Waktu: $dateDisplay WIB',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr(ch: '-');

    // 3. Rincian Pelanggan & Tagihan
    bytes += generator.row([
      PosColumn(text: 'Pelanggan', width: is80mm ? 4 : 5),
      PosColumn(text: ': $customerName', width: is80mm ? 8 : 7, styles: const PosStyles(bold: true)),
    ]);

    if (idpl != null && idpl.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'ID Pelanggan', width: is80mm ? 4 : 5),
        PosColumn(text: ': $idpl', width: is80mm ? 8 : 7),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'Periode', width: is80mm ? 4 : 5),
      PosColumn(text: ': $period', width: is80mm ? 8 : 7),
    ]);

    // Evaluasi status yang tepat secara cerdas & matematis
    final actualPaid = paidAmount > 0 ? paidAmount : totalAmount;
    String resolvedStatus = status.toLowerCase().trim();
    if (resolvedStatus == 'paid' || resolvedStatus == 'lunas') {
      resolvedStatus = 'paid';
    } else if (resolvedStatus == 'partially_paid' || resolvedStatus == 'installment' || resolvedStatus == 'cicilan') {
      resolvedStatus = 'partially_paid';
    } else {
      // Jika status dikirim masih 'unpaid' tapi sudah ada pembayaran
      if (actualPaid >= totalAmount && totalAmount > 0) {
        resolvedStatus = 'paid';
      } else if (actualPaid > 0 && actualPaid < totalAmount) {
        resolvedStatus = 'partially_paid';
      }
    }

    final isCicilan = resolvedStatus == 'partially_paid';
    final statusText = resolvedStatus == 'paid'
        ? 'LUNAS'
        : (isCicilan ? 'CICILAN' : 'BELUM BAYAR');

    bytes += generator.row([
      PosColumn(text: 'Status', width: is80mm ? 4 : 5),
      PosColumn(text: ': $statusText', width: is80mm ? 8 : 7, styles: const PosStyles(bold: true)),
    ]);

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Metode Bayar', width: is80mm ? 4 : 5),
        PosColumn(text: ': ${paymentMethod.toUpperCase()}', width: is80mm ? 8 : 7),
      ]);
    }

    bytes += generator.hr(ch: '-');

    // 4. Nominal Tagihan & Jumlah Bayar
    bytes += generator.row([
      PosColumn(text: 'Total Tagihan', width: is80mm ? 5 : 6),
      PosColumn(
        text: currencyFormat.format(totalAmount),
        width: is80mm ? 7 : 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Jumlah Bayar', width: is80mm ? 5 : 6),
      PosColumn(
        text: currencyFormat.format(actualPaid),
        width: is80mm ? 7 : 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (isCicilan) {
      final sisa = totalAmount - actualPaid;
      bytes += generator.row([
        PosColumn(text: 'Sisa Tagihan', width: is80mm ? 5 : 6),
        PosColumn(
          text: currencyFormat.format(sisa > 0 ? sisa : 0),
          width: is80mm ? 7 : 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // 5. Catatan Footer Dinamis
    if (adminName != null && adminName.isNotEmpty) {
      bytes += generator.text(
        'Kasir/Petugas: $adminName',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    final footerContent = (receiptFooter != null && receiptFooter.trim().isNotEmpty)
        ? receiptFooter.trim()
        : (_receiptFooter != null && _receiptFooter!.trim().isNotEmpty
            ? _receiptFooter!.trim()
            : 'Terima kasih atas pembayaran Anda.\nSimpan struk ini sebagai bukti pembayaran sah.');

    for (final line in footerContent.split('\n')) {
      final cleanLine = line.trim();
      if (cleanLine.isNotEmpty) {
        bytes += generator.text(
          cleanLine,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}

