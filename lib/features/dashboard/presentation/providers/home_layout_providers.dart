import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/dashboard/domain/home_layout.dart';
import 'package:hishab/features/dashboard/domain/setup_steps.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// The parts of Home that were put away.
final homeHiddenProvider = StreamProvider<Set<HomeSection>>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchAll()
      .map((saved) => parseHiddenSections(saved[homeHiddenKey])),
);

/// Puts [section] of Home away, or brings it back.
Future<void> setHomeSectionHidden(
  ProviderContainer container,
  HomeSection section, {
  required bool away,
}) async {
  final db = container.read(appDatabaseProvider);
  final saved = parseHiddenSections(
    (await db.settingsDao.getAll())[homeHiddenKey],
  );
  await db.settingsDao.put(
    homeHiddenKey,
    encodeHiddenSections(withSectionHidden(saved, section, away: away)),
  );
}

/// True once the setup checklist was put away.
final setupDismissedProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchAll()
      .map((saved) => saved[setupDismissedKey] == 'true'),
);

/// How far along the first things are: an entry, a budget, a backup, Drive.
final setupProgressProvider = FutureProvider.autoDispose<SetupProgress>((
  ref,
) async {
  ref.watch(dataChangesProvider);
  final db = ref.read(appDatabaseProvider);
  final now = ref.read(clockProvider)();
  final info = ref.watch(backupInfoProvider).value;
  final drive = ref.watch(driveBackupStatusProvider).value;
  return setupProgressOf(
    hasEntry: await db.entryCount(DateTime(2000), DateTime(2200)) > 0,
    hasBudget: await BudgetsRepository(db).overallBudget(now) != null,
    hasBackup: info?.lastBackup != null,
    driveOn: drive?.enabled ?? false,
  );
});
