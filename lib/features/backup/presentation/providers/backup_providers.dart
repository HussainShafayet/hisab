import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/backup_reminder.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(appDatabaseProvider)),
);

final csvImportRepositoryProvider = Provider<CsvImportRepository>(
  (ref) => CsvImportRepository(ref.watch(appDatabaseProvider)),
);

/// The latest CSV import that can still be undone, or null.
final lastImportProvider = StreamProvider.autoDispose<ImportBatch?>(
  (ref) => ref.watch(csvImportRepositoryProvider).watchLastBatch(),
);

/// When this phone last made a backup, and until when the reminder is put off.
final backupInfoProvider = StreamProvider.autoDispose<BackupInfo>(
  (ref) => ref.watch(backupRepositoryProvider).watchInfo(),
);

/// How many entries there are, to leave a new install without a reminder.
final _entryCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(dataChangesProvider);
  return ref
      .read(appDatabaseProvider)
      .entryCount(DateTime(2000), DateTime(2100));
});

/// Whether Home should ask for a backup, and since when. Null when not.
final backupDueProvider = Provider.autoDispose<BackupDue?>((ref) {
  final info = ref.watch(backupInfoProvider).value;
  final count = ref.watch(_entryCountProvider).value;
  final enabled = ref.watch(
    preferencesProvider.select((p) => p.backupReminder),
  );
  if (info == null || count == null) return null;
  return backupDue(
    now: ref.read(clockProvider)(),
    info: info,
    entryCount: count,
    enabled: enabled,
  );
});
