import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/settings/domain/more_status.dart';

/// The places of the More list opened last, newest first.
final moreRecentProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchAll()
      .map((saved) => parseRecent(saved[moreRecentKey])),
);

/// Remembers that [route] was opened from the More list.
Future<void> rememberMoreVisit(
  ProviderContainer container,
  String route,
) async {
  final db = container.read(appDatabaseProvider);
  final saved = (await db.settingsDao.getAll())[moreRecentKey];
  await db.settingsDao.put(
    moreRecentKey,
    rememberVisit(parseRecent(saved), route).join(','),
  );
}

/// How a few places stand, by route: loans that are late, the backup, the next
/// recurring item.
final moreStatusProvider = Provider.autoDispose<Map<String, MoreStatus>>((ref) {
  final now = ref.watch(clockProvider)();
  final result = <String, MoreStatus>{};

  final debts = ref.watch(debtsProvider).value;
  if (debts != null) {
    final late = loansStatus(debtTotals(debts, now).overdueCount);
    if (late != null) result[AppRoutes.debts] = late;
  }

  final info = ref.watch(backupInfoProvider).value;
  if (info != null) {
    final last = info.lastBackup;
    result[AppRoutes.backup] = backupStatus(
      last == null ? null : daysBetween(dateOnly(last), dateOnly(now)),
    );
  }

  final rules = ref.watch(recurringRulesProvider).value;
  if (rules != null) {
    int? soonest;
    for (final rule in rules) {
      if (!rule.isActive) continue;
      final days = daysBetween(dateOnly(now), rule.nextDue);
      if (days < 0) continue;
      if (soonest == null || days < soonest) soonest = days;
    }
    final recurring = recurringStatus(soonest);
    if (recurring != null) result[AppRoutes.recurring] = recurring;
  }
  return result;
});
