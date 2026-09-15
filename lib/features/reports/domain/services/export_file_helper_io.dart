import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export_file_helper.dart';

class _ExportFileHelperIo implements ExportFileHelper {
  static const MethodChannel _fileChannel = MethodChannel('gate_reco/files');

  @override
  Future<void> saveAndShare({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final uniqueName = _withTimestamp(fileName);

    if (Platform.isAndroid) {
      await _saveToAndroidDownloads(
        fileName: uniqueName,
        bytes: bytes,
        mimeType: mimeType,
      );
      return;
    }

    // iOS: no public Downloads folder without user interaction. Share sheet
    // lets the user pick "Save to Files" or any other target.
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$uniqueName');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      text: 'Exported $uniqueName',
      // iPad requires a source rect for the popover anchor; the top-left of
      // the screen is a safe default that avoids the "presented view has no
      // source view" crash on iOS 17+.
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> _saveToAndroidDownloads({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    try {
      final savedUri = await _fileChannel.invokeMethod<String>(
        'saveFileToDownloads',
        <String, dynamic>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': Uint8List.fromList(bytes),
        },
      );
      if (savedUri == null || savedUri.isEmpty) {
        throw Exception('Downloads folder returned an empty save path');
      }
    } on PlatformException catch (e) {
      throw Exception(
        'Could not save file to Downloads folder: ${e.message ?? e.code}',
      );
    }
  }

  // Reports currently hardcode names like `GateEntryRegister.xlsx`. Without a
  // suffix, MediaStore auto-renames on API 29+ (users can't tell which is
  // which) and legacy Android silently overwrites the prior file. Insert a
  // timestamp before the extension so each export is uniquely identifiable.
  String _withTimestamp(String fileName) {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return '${fileName}_$stamp';
    return '${fileName.substring(0, dot)}_$stamp${fileName.substring(dot)}';
  }
}

final ExportFileHelper exportFileHelper = _ExportFileHelperIo();
