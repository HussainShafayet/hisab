import 'dart:convert';
import 'dart:typed_data';

import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// Keeps a copy of the data in the person's Google Drive: one file, written
/// over each time. See docs/specs/backup/google-drive-backup.md.
class DriveBackupService {
  const DriveBackupService({
    required this.db,
    required this.repository,
    required this.gateway,
  });

  final AppDatabase db;
  final BackupRepository repository;
  final DriveGateway gateway;

  /// Turns it on: asks the person to sign in, remembers the account and saves
  /// a first copy. Throws [DriveException] when the sign-in fails or is
  /// closed; a problem with the first copy is kept for the screen to show.
  Future<void> turnOn(DateTime now) async {
    final email = await gateway.signIn();
    await db.settingsDao.put(driveEmailKey, email);
    await db.settingsDao.put(driveEnabledKey, 'true');
    await db.settingsDao.put(driveProblemKey, null);
    await db.settingsDao.put(driveDetailKey, null);
    await run(now);
  }

  /// Turns it off and forgets the account on this phone. What is already in
  /// Drive stays there.
  Future<void> turnOff() async {
    for (final key in [
      driveEnabledKey,
      driveEmailKey,
      driveProblemKey,
      driveDetailKey,
    ]) {
      await db.settingsDao.put(key, null);
    }
    await gateway.signOut();
  }

  /// Saves a copy at [now] when it is on. Nothing is written while there is no
  /// entry. Returns whether the file was written. A problem is kept (see
  /// [DriveBackupStatus]) and not thrown.
  Future<bool> run(DateTime now) async {
    final saved = await db.settingsDao.getAll();
    if (saved[driveEnabledKey] != 'true') return false;
    if (await db.entryCount(DateTime(2000), DateTime(2100)) == 0) return false;
    try {
      final backup = await repository.buildBackup(now);
      await gateway.upload(
        driveBackupFileName,
        Uint8List.fromList(utf8.encode(backup.encode())),
      );
      await db.settingsDao.put(lastDriveBackupKey, now.toIso8601String());
      // A copy off the phone is a backup: Home stops asking for one.
      await repository.markBackedUp(now);
      await db.settingsDao.put(driveProblemKey, null);
      await db.settingsDao.put(driveDetailKey, null);
      return true;
    } on DriveException catch (error) {
      await db.settingsDao.put(driveProblemKey, error.problem.name);
      await db.settingsDao.put(driveDetailKey, error.detail);
    } on Object catch (error) {
      await db.settingsDao.put(driveProblemKey, DriveProblem.failed.name);
      await db.settingsDao.put(driveDetailKey, '$error');
    }
    return false;
  }

  /// The backup kept in Drive, or null when there is none. Asks the person to
  /// sign in when no account is signed in on this phone. Throws
  /// [DriveException], and [FormatException] when the file is not a backup.
  Future<BackupData?> fetch() async {
    DriveFile? file;
    try {
      file = await gateway.download(driveBackupFileName);
    } on DriveException catch (error) {
      if (error.problem != DriveProblem.needsSignIn) rethrow;
      final email = await gateway.signIn();
      await db.settingsDao.put(driveEmailKey, email);
      file = await gateway.download(driveBackupFileName);
    }
    if (file == null) return null;
    return BackupData.decode(utf8.decode(file.bytes));
  }
}

/// What the backup to Google Drive did last.
class DriveBackupStatus {
  const DriveBackupStatus({
    this.enabled = false,
    this.email,
    this.lastSaved,
    this.problem,
    this.detail,
  });

  final bool enabled;
  final String? email;
  final DateTime? lastSaved;
  final DriveProblem? problem;
  final String? detail;

  factory DriveBackupStatus.fromSettings(Map<String, String> saved) {
    final name = saved[driveProblemKey];
    return DriveBackupStatus(
      enabled: saved[driveEnabledKey] == 'true',
      email: saved[driveEmailKey],
      lastSaved: DateTime.tryParse(saved[lastDriveBackupKey] ?? ''),
      problem: DriveProblem.values
          .where((problem) => problem.name == name)
          .firstOrNull,
      detail: saved[driveDetailKey],
    );
  }
}
