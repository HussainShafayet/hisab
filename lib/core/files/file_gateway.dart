import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// A file the user chose.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Saving, sharing and picking files, behind one small interface. The real
/// implementation uses the phone's file dialogs and share sheet, which tests
/// cannot open, so tests give the app a fake one.
abstract interface class FileGateway {
  /// Asks where to save [bytes] as [fileName]. Returns false when the user
  /// cancelled.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Opens the share sheet for a file, to send it to another app.
  Future<void> share({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Opens the share sheet with a piece of [text], for a message to send.
  Future<void> shareText(String text);

  /// Asks the user to choose a file with one of [extensions] (without the
  /// dot). Returns null when the user cancelled.
  Future<PickedFile?> pick({required List<String> extensions});
}

class PluginFileGateway implements FileGateway {
  const PluginFileGateway();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return saved != null;
  }

  @override
  Future<void> share({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
  }

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Future<PickedFile?> pick({required List<String> extensions}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedFile(name: file.name, bytes: bytes);
  }
}

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const PluginFileGateway(),
);
