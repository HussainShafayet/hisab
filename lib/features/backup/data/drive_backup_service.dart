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
  Future<bool> run(DateTime now) async =>
      await attempt(now) == DriveRunResult.saved;

  /// Like [run], but says what happened, for the "Back up now" button.
  Future<DriveRunResult> attempt(DateTime now) async {
    final saved = await db.settingsDao.getAll();
    if (saved[driveEnabledKey] != 'true') return DriveRunResult.off;
    if (await db.entryCount(DateTime(2000), DateTime(2100)) == 0) {
      return DriveRunResult.nothingToSave;
    }
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
      await _log(saved[driveLogKey], DriveLogEntry(at: now, ok: true));
      return DriveRunResult.saved;
    } on DriveException catch (error) {
      await db.settingsDao.put(driveProblemKey, error.problem.name);
      await db.settingsDao.put(driveDetailKey, error.detail);
      await _log(
        saved[driveLogKey],
        DriveLogEntry(at: now, ok: false, problem: error.problem.name),
      );
    } on Object catch (error) {
      await db.settingsDao.put(driveProblemKey, DriveProblem.failed.name);
      await db.settingsDao.put(driveDetailKey, '$error');
      await _log(
        saved[driveLogKey],
        DriveLogEntry(at: now, ok: false, problem: DriveProblem.failed.name),
      );
    }
    return DriveRunResult.failed;
  }

  Future<void> _log(String? before, DriveLogEntry entry) => db.settingsDao.put(
    driveLogKey,
    DriveLogEntry.encodeAll([entry, ...DriveLogEntry.decodeAll(before)]),
  );

  /// Looks in Drive for the backup and says what is there, to settle "did it
  /// really save?". Asks the person to sign in when no account is signed in on
  /// this phone. Throws [DriveException], and [FormatException] when the file
  /// is not a backup.
  Future<DriveCheck> check() async {
    final file = await _download();
    if (file == null) return const DriveCheck(found: false);
    final data = BackupData.decode(utf8.decode(file.bytes));
    return DriveCheck(
      found: true,
      modified: file.modified,
      bytes: file.bytes.length,
      transactions: data.transactions.length,
      accounts: data.accounts.length,
      categories: data.categories.length,
    );
  }

  Future<DriveFile?> _download() async {
    try {
      return await gateway.download(driveBackupFileName);
    } on DriveException catch (error) {
      if (error.problem != DriveProblem.needsSignIn) rethrow;
      final email = await gateway.signIn();
      await db.settingsDao.put(driveEmailKey, email);
      return gateway.download(driveBackupFileName);
    }
  }

  /// The backup kept in Drive, or null when there is none. Asks the person to
  /// sign in when no account is signed in on this phone. Throws
  /// [DriveException], and [FormatException] when the file is not a backup.
  Future<BackupData?> fetch() async {
    final file = await _download();
    if (file == null) return null;
    return BackupData.decode(utf8.decode(file.bytes));
  }
}

/// What a try of the Drive backup came to.
enum DriveRunResult {
  /// The file was written.
  saved,

  /// The backup is switched off.
  off,

  /// There is no entry yet, so nothing was written.
  nothingToSave,

  /// Something went wrong; the problem is kept.
  failed,
}

/// What is in Drive, as [DriveBackupService.check] found it.
class DriveCheck {
  const DriveCheck({
    required this.found,
    this.modified,
    this.bytes = 0,
    this.transactions = 0,
    this.accounts = 0,
    this.categories = 0,
  });

  final bool found;

  /// When Drive says the file was last changed.
  final DateTime? modified;
  final int bytes;
  final int transactions;
  final int accounts;
  final int categories;
}

/// One try of the Drive backup, kept so the person can see that it ran.
class DriveLogEntry {
  const DriveLogEntry({required this.at, required this.ok, this.problem});

  final DateTime at;
  final bool ok;

  /// A [DriveProblem] name when it did not work.
  final String? problem;

  static String encodeAll(List<DriveLogEntry> entries) => jsonEncode([
    for (final entry in entries.take(maxDriveLog))
      {
        'at': entry.at.toIso8601String(),
        'ok': entry.ok,
        'problem': entry.problem,
      },
  ]);

  static List<DriveLogEntry> decodeAll(String? text) {
    if (text == null || text.isEmpty) return const [];
    try {
      final list = jsonDecode(text);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map && DateTime.tryParse('${item['at']}') != null)
            DriveLogEntry(
              at: DateTime.parse('${item['at']}'),
              ok: item['ok'] == true,
              problem: item['problem'] as String?,
            ),
      ];
    } on FormatException {
      return const [];
    }
  }
}

/// How many tries are kept.
const maxDriveLog = 10;

/// What the backup to Google Drive did last.
class DriveBackupStatus {
  const DriveBackupStatus({
    this.enabled = false,
    this.email,
    this.lastSaved,
    this.problem,
    this.detail,
    this.log = const [],
  });

  final bool enabled;
  final String? email;
  final DateTime? lastSaved;
  final DriveProblem? problem;
  final String? detail;

  /// The last tries, newest first.
  final List<DriveLogEntry> log;

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
      log: DriveLogEntry.decodeAll(saved[driveLogKey]),
    );
  }
}
