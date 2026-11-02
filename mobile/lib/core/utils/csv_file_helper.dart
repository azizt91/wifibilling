import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CsvFileHelper {
  /// Menyimpan bytes biner ke file lokal (folder Download / File Picker)
  static Future<String?> saveBytes({
    required String fileName,
    required List<int> bytes,
    required String extension,
    String? dialogTitle,
  }) async {
    final byteData = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // 1. Coba gunakan FilePicker save dialog (memungkinkan user memilih folder)
    try {
      final pickedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Simpan File ${extension.toUpperCase()}',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: byteData,
      );
      if (pickedPath != null && pickedPath.isNotEmpty) {
        final file = File(pickedPath);
        if (!await file.exists() || (await file.length()) == 0) {
          await file.writeAsBytes(byteData);
        }
        return pickedPath;
      }
    } catch (_) {}

    // 2. Coba simpan langsung ke folder Download publik Android
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(byteData);
        return file.path;
      }
    } catch (_) {}

    // 3. Fallback ke sistem getDownloadsDirectory atau Documents
    try {
      final dir = await getDownloadsDirectory() ??
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData);
      return file.path;
    } catch (_) {}

    return null;
  }

  /// Menyimpan string CSV ke file lokal (folder Download / File Picker)
  /// dengan encoding UTF-8 + BOM agar terbaca sempurna di Microsoft Excel.
  static Future<String?> saveCsv({
    required String fileName,
    required String content,
  }) async {
    final bytes = utf8.encode('\uFEFF$content');
    final savedPath = await saveBytes(
      fileName: fileName,
      bytes: bytes,
      extension: 'csv',
      dialogTitle: 'Simpan File CSV / Excel',
    );

    // Fallback terakhir: salin ke clipboard jika penyimpanan disk tidak dapat diakses
    if (savedPath == null) {
      try {
        await Clipboard.setData(ClipboardData(text: content));
      } catch (_) {}
    }

    return savedPath;
  }

  /// Menyimpan file PDF ke file lokal (folder Download / File Picker)
  static Future<String?> savePdf({
    required String fileName,
    required List<int> bytes,
  }) async {
    return saveBytes(
      fileName: fileName,
      bytes: bytes,
      extension: 'pdf',
      dialogTitle: 'Simpan File PDF',
    );
  }

  /// Membuka file dengan aplikasi default viewer di perangkat (PDF viewer, Excel/Sheets, dsb)
  static Future<OpenResult> openFile(String filePath) async {
    try {
      return await OpenFilex.open(filePath);
    } catch (e) {
      return OpenResult(type: ResultType.error, message: e.toString());
    }
  }
}


