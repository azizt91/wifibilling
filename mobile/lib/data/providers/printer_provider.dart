import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/services/thermal_printer_service.dart';

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

class PrinterState {
  final bool isConnected;
  final bool isScanning;
  final bool isConnecting;
  final String? connectedName;
  final String? connectedMac;
  final List<BluetoothInfo> availableDevices;
  final ThermalPaperSize paperSize;
  final String? errorMessage;

  PrinterState({
    this.isConnected = false,
    this.isScanning = false,
    this.isConnecting = false,
    this.connectedName,
    this.connectedMac,
    this.availableDevices = const [],
    this.paperSize = ThermalPaperSize.mm58,
    this.errorMessage,
  });

  PrinterState copyWith({
    bool? isConnected,
    bool? isScanning,
    bool? isConnecting,
    String? connectedName,
    String? connectedMac,
    List<BluetoothInfo>? availableDevices,
    ThermalPaperSize? paperSize,
    String? errorMessage,
  }) {
    return PrinterState(
      isConnected: isConnected ?? this.isConnected,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      connectedName: connectedName ?? this.connectedName,
      connectedMac: connectedMac ?? this.connectedMac,
      availableDevices: availableDevices ?? this.availableDevices,
      paperSize: paperSize ?? this.paperSize,
      errorMessage: errorMessage,
    );
  }
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  final ThermalPrinterService _service;

  PrinterNotifier(this._service) : super(PrinterState()) {
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    final connected = await _service.isConnected();
    state = state.copyWith(
      isConnected: connected,
      connectedName: _service.connectedName,
      connectedMac: _service.connectedMac,
      paperSize: _service.paperSize,
    );
    if (!connected) {
      // Coba auto connect ke printer terakhir
      autoConnect();
    }
  }

  Future<void> scanDevices() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      final isBtOn = await _service.isBluetoothEnabled();
      if (!isBtOn) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: 'Bluetooth pada perangkat belum aktif. Silakan aktifkan Bluetooth.',
        );
        return;
      }

      // Pastikan izin Bluetooth diberikan oleh pengguna
      final hasPermission = await _service.checkAndRequestBluetoothPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: 'Izin "Perangkat di sekitar" (Nearby Devices) diperlukan untuk mendeteksi printer Bluetooth.',
        );
        return;
      }

      final devices = await _service.getPairedDevices();
      final connected = await _service.isConnected();

      state = state.copyWith(
        isScanning: false,
        availableDevices: devices,
        isConnected: connected,
        errorMessage: devices.isEmpty && !connected
            ? 'Belum ada printer Bluetooth terdeteksi. Pastikan printer dinyalakan dan sudah di-pair di menu Bluetooth HP.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Gagal memindai perangkat: $e',
      );
    }
  }

  Future<bool> connect(String macAddress, String deviceName) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);
    try {
      final success = await _service.connect(macAddress, deviceName: deviceName);
      state = state.copyWith(
        isConnecting: false,
        isConnected: success,
        connectedName: success ? deviceName : null,
        connectedMac: success ? macAddress : null,
        errorMessage: success ? null : 'Gagal menghubungkan ke printer $deviceName',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: 'Terjadi kesalahan saat menghubungkan: $e',
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = state.copyWith(
      isConnected: false,
      connectedName: null,
      connectedMac: null,
    );
  }

  Future<void> autoConnect() async {
    if (_service.connectedMac == null) return;
    state = state.copyWith(isConnecting: true);
    final ok = await _service.autoConnect();
    state = state.copyWith(
      isConnecting: false,
      isConnected: ok,
      connectedName: ok ? _service.connectedName : null,
      connectedMac: ok ? _service.connectedMac : null,
    );
  }

  Future<void> setPaperSize(ThermalPaperSize size) async {
    await _service.setPaperSize(size);
    state = state.copyWith(paperSize: size);
  }

  Future<bool> testPrint({String? storeName}) async {
    try {
      return await _service.printTestReceipt(storeName: storeName);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  final service = ref.watch(thermalPrinterServiceProvider);
  return PrinterNotifier(service);
});

