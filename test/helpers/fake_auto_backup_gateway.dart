import 'dart:typed_data';

import 'package:hishab/features/backup/data/auto_backup_gateway.dart';

/// An automatic backup that keeps the files in memory instead of writing to
/// Downloads, and can be told to fail.
class FakeAutoBackupGateway implements AutoBackupGateway {
  final saved = <({String name, Uint8List bytes})>[];

  /// When set, saving throws this.
  AutoBackupProblem? failWith;

  @override
  Future<void> saveToDownloads(String name, Uint8List bytes) async {
    final problem = failWith;
    if (problem != null) throw AutoBackupException(problem);
    saved.add((name: name, bytes: bytes));
  }
}
