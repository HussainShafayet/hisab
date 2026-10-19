import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/reminders/data/alert_queries.dart';
import 'package:hishab/features/reminders/domain/alerts.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// The newest entry this run of the app has seen. Alerts only come for an
/// entry written while the app runs, never for what was already there.
class _Seen {
  bool started = false;
  int? id;
}

final _seenProvider = Provider<_Seen>((ref) => _Seen());

/// Watches the entries and, when a new expense is written, shows the budget
/// alert (nearly used, crossed) and the habit alert (the same kind of spending
/// again and again), each at most once as described in the spec. It also takes
/// today's daily reminder off the schedule once something is written today.
/// Kept alive by `HishabApp`.
final alertWatcherProvider = FutureProvider<void>((ref) async {
  ref.watch(dataChangesProvider);
  final preferences = ref.watch(preferencesProvider);
  final db = ref.read(appDatabaseProvider);
  final scheduler = ref.read(reminderSchedulerProvider);
  final now = ref.read(clockProvider)();
  final seen = ref.read(_seenProvider);

  final latest = await db.latestEntry();
  final isNew = seen.started && latest != null && latest.id > (seen.id ?? 0);
  seen.started = true;
  seen.id = latest?.id ?? seen.id;

  final today = dateOnly(now);
  if (preferences.dailyReminder &&
      await db.entryCount(today, today.add(const Duration(days: 1))) > 0) {
    await scheduler.cancel([dailyReminderId(now)]);
  }
  if (!isNew || !latest.isExpense) return;

  final markers = await db.settingsDao.getAll();
  Future<void> remember(String key, String value) =>
      db.settingsDao.put(key, value);

  if (preferences.budgetAlerts) {
    final budget = await BudgetsRepository(db).overallBudget(now);
    if (budget != null) {
      final percent = budget.progress.percent;
      final step = budgetStepOf(percent);
      final key = 'alert_budget_${now.year}-${now.month}';
      final told = BudgetStep.values.asNameMap()[markers[key]];
      if (step.index > (told ?? BudgetStep.none).index) {
        await remember(key, step.name);
        final alert = budgetAlertFor(
          step,
          percent: percent,
          overBy: budget.spent - budget.limit,
          now: now,
        );
        if (alert != null) {
          await scheduler.showNow(alert, funSounds: preferences.funSounds);
        }
      }
    }
  }

  final categoryId = latest.categoryId;
  if (preferences.habitAlerts && categoryId != null) {
    final since = today.subtract(const Duration(days: habitDays - 1));
    final stats = await db.expensesSince(categoryId, since);
    final key = 'alert_habit_$categoryId';
    final day = '${today.year}-${today.month}-${today.day}';
    final name = await db.categoryNameOf(categoryId);
    if (name != null && isHabit(stats.count) && markers[key] != day) {
      await remember(key, day);
      await scheduler.showNow(
        habitAlertFor(
          categoryId: categoryId,
          category: name,
          count: stats.count,
          total: stats.total,
          now: now,
        ),
        funSounds: preferences.funSounds,
      );
    }
  }
});
