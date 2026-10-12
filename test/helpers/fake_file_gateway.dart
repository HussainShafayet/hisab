import 'dart:convert';
import 'dart:typed_data';

import 'package:hishab/core/files/file_gateway.dart';

/// A file the app asked to save or share.
class DeliveredFile {
  const DeliveredFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  String get text => utf8.decode(bytes);
}

/// A [FileGateway] for tests: it records what was saved and shared, and
/// hands out the file it was given when the app asks to pick one.
class FakeFileGateway implements FileGateway {
  FakeFileGateway({this.picked, this.saveResult = true});

  /// What [pick] returns. Null means the user cancelled.
  PickedFile? picked;

  /// What [save] returns: false means the user cancelled the dialog.
  bool saveResult;

  /// When set, every call throws it, like a failing plugin.
  Object? failure;

  final saved = <DeliveredFile>[];
  final shared = <DeliveredFile>[];
  final pickRequests = <List<String>>[];

  /// The texts that were sent to the share sheet.
  final sharedTexts = <String>[];

  /// Makes [pick] return a file with this text.
  void pickText(String name, String text) {
    picked = PickedFile(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (failure != null) throw failure!;
    saved.add(
      DeliveredFile(fileName: fileName, bytes: bytes, mimeType: mimeType),
    );
    return saveResult;
  }

  @override
  Future<void> shareText(String text) async {
    if (failure != null) throw failure!;
    sharedTexts.add(text);
  }

  @override
  Future<void> share({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (failure != null) throw failure!;
    shared.add(
      DeliveredFile(fileName: fileName, bytes: bytes, mimeType: mimeType),
    );
  }

  @override
  Future<PickedFile?> pick({required List<String> extensions}) async {
    if (failure != null) throw failure!;
    pickRequests.add(extensions);
    return picked;
  }
}
