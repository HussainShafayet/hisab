import 'dart:convert';
import 'dart:typed_data';

import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// The file the automatic backup writes, in Downloads/Hishab.
const autoBackupFileName = 'Hishab-auto-backup.json';

/// Writes the automatic backup: a copy of everything, in a file that stays
/// when the app is removed.
class AutoBackupService {
  const AutoBackupService({
    required this.db,
    required this.repository,
    required this.gateway,
  });

  final AppDatabase db;
  final BackupRepository repository;
  final AutoBackupGateway gateway;

  /// Saves the backup at [now]. Nothing is written while there is no entry, so
  /// a new install does not leave an empty file. Returns whether the file was
  /// written. A problem is kept (see [AutoBackupStatus]) and not thrown.
  Future<bool> run(DateTime now) async {
    if (await db.entryCount(DateTime(2000), DateTime(2100)) == 0) {
      return false;
    }
    try {
      final backup = await repository.buildBackup(now);
      await gateway.saveToDownloads(
        autoBackupFileName,
        Uint8List.fromList(utf8.encode(backup.encode())),
      );
      await db.settingsDao.put(lastAutoBackupKey, now.toIso8601String());
      await db.settingsDao.put(autoBackupProblemKey, null);
      return true;
    } on AutoBackupException catch (error) {
      await db.settingsDao.put(autoBackupProblemKey, error.problem.name);
    } on Object {
      await db.settingsDao.put(
        autoBackupProblemKey,
        AutoBackupProblem.failed.name,
      );
    }
    return false;
  }
}

/// What the automatic backup did last.
class AutoBackupStatus {
  const AutoBackupStatus({this.lastSaved, this.problem});

  final DateTime? lastSaved;
  final AutoBackupProblem? problem;

  factory AutoBackupStatus.fromSettings(Map<String, String> saved) {
    final name = saved[autoBackupProblemKey];
    return AutoBackupStatus(
      lastSaved: DateTime.tryParse(saved[lastAutoBackupKey] ?? ''),
      problem: AutoBackupProblem.values
          .where((problem) => problem.name == name)
          .firstOrNull,
    );
  }
}
