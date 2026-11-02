import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerLocationPickerWidget extends StatefulWidget {
  final TextEditingController latController;
  final TextEditingController lngController;

  const CustomerLocationPickerWidget({
    super.key,
    required this.latController,
    required this.lngController,
  });

  @override
  State<CustomerLocationPickerWidget> createState() => _CustomerLocationPickerWidgetState();
}

class _CustomerLocationPickerWidgetState extends State<CustomerLocationPickerWidget> {
  bool _isLocating = false;
  String? _accuracyInfo;

  @override
  void initState() {
    super.initState();
    widget.latController.addListener(_onCoordsChanged);
    widget.lngController.addListener(_onCoordsChanged);
  }

  @override
  void dispose() {
    widget.latController.removeListener(_onCoordsChanged);
    widget.lngController.removeListener(_onCoordsChanged);
    super.dispose();
  }

  void _onCoordsChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasCoordinates {
    final lat = double.tryParse(widget.latController.text.trim());
    final lng = double.tryParse(widget.lngController.text.trim());
    return lat != null && lng != null;
  }

  /// Ekstraksi Latitude & Longitude dari string atau link Google Maps
  static Map<String, double>? parseCoordinates(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    // 1. Format @lat,lng (contoh URL desktop Google Maps)
    final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final atMatch = atRegex.firstMatch(text);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    // 2. Format query parameter q=lat,lng atau ll=lat,lng
    final queryRegex = RegExp(r'[?&](?:q|ll|query)=(-?\d+\.\d+),(-?\d+\.\d+)');
    final queryMatch = queryRegex.firstMatch(text);
    if (queryMatch != null) {
      final lat = double.tryParse(queryMatch.group(1)!);
      final lng = double.tryParse(queryMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    // 3. Format koordinat biasa: "-6.9174639, 107.6191228" atau "-6.9174639 107.6191228"
    final coordRegex = RegExp(r'(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)');
    final coordMatch = coordRegex.firstMatch(text);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    return null;
  }

  /// 1-Tap GPS Device Location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS tidak aktif. Mohon aktifkan GPS perangkat Anda.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin akses lokasi ditolak.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak permanen. Silakan aktifkan via Pengaturan HP.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      widget.latController.text = position.latitude.toStringAsFixed(7);
      widget.lngController.text = position.longitude.toStringAsFixed(7);

      setState(() {
        _accuracyInfo = 'Akurasi GPS: ±${position.accuracy.toStringAsFixed(1)} m';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lokasi berhasil diambil ($_accuracyInfo)'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil lokasi GPS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Smart Paste dari Clipboard / Dialog
  Future<void> _handleSmartPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';

      final coords = parseCoordinates(text);
      if (coords != null) {
        widget.latController.text = coords['lat']!.toStringAsFixed(7);
        widget.lngController.text = coords['lng']!.toStringAsFixed(7);
        setState(() {
          _accuracyInfo = 'Ditempel dari Clipboard';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Koordinat berhasil diekstrak: ${coords['lat']}, ${coords['lng']}'),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        }
        return;
      }
    } catch (_) {
      // Abaikan jika clipboard gagal dibaca, buka modal input manual
    }

    if (!mounted) return;
    _showPasteDialog();
  }

  /// Dialog Tempel Link / WhatsApp Share Loc
  void _showPasteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF625095)),
            SizedBox(width: 8),
            Text('Tempel Link / Teks Maps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempel link Google Maps atau pesan share location dari WhatsApp di bawah ini:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh:\nhttps://maps.google.com/?q=-6.9174,107.6191\natau -6.9174639, 107.6191228',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF3ECE8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF625095),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final result = parseCoordinates(controller.text);
              if (result != null) {
                widget.latController.text = result['lat']!.toStringAsFixed(7);
                widget.lngController.text = result['lng']!.toStringAsFixed(7);
                setState(() {
                  _accuracyInfo = 'Ditempel dari link/teks';
                });
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Koordinat berhasil diekstrak: ${result['lat']}, ${result['lng']}'),
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                );
              } else {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak dapat menemukan koordinat dalam teks yang ditempel.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Terapkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Buka lokasi di Google Maps untuk verifikasi
  Future<void> _openInMaps() async {
    final lat = widget.latController.text.trim();
    final lng = widget.lngController.text.trim();
    if (lat.isEmpty || lng.isEmpty) return;

    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka aplikasi Maps.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka Maps: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lokasi Pelanggan (GPS / Koordinat)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF110E1B)),
            ),
            if (_hasCoordinates)
              InkWell(
                onTap: _openInMaps,
                child: const Row(
                  children: [
                    Icon(Icons.map_outlined, size: 14, color: Color(0xFF625095)),
                    SizedBox(width: 4),
                    Text('Lihat Maps', style: TextStyle(fontSize: 12, color: Color(0xFF625095), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 2 Tombol Aksi Cepat
        Row(
          children: [
            // Tombol 1: Ambil Lokasi Saya
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDE9FE),
                  foregroundColor: const Color(0xFF5B21B6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B21B6)),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  _isLocating ? 'Mencari...' : 'Lokasi Saya',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tombol 2: Tempel Link / Share Loc WA
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleSmartPaste,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF047857),
                  backgroundColor: const Color(0xFFECFDF5),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.paste_rounded, size: 18),
                label: const Text(
                  'Tempel WA/Maps',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Kolom Latitude & Longitude
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  hintText: '-6.9174639',
                  filled: true,
                  fillColor: const Color(0xFFEAE8F3),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: widget.lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  hintText: '107.6191228',
                  filled: true,
                  fillColor: const Color(0xFFEAE8F3),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _accuracyInfo ?? 'Otomatis atau ketik manual (Opsional)',
              style: TextStyle(
                fontSize: 11,
                color: _accuracyInfo != null ? const Color(0xFF047857) : Colors.grey[500],
                fontWeight: _accuracyInfo != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (_hasCoordinates)
              GestureDetector(
                onTap: () {
                  widget.latController.clear();
                  widget.lngController.clear();
                  setState(() => _accuracyInfo = null);
                },
                child: const Text('Hapus', style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
          ],
        ),
      ],
    );
  }
}

