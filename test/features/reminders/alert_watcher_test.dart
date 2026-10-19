import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/reminders/domain/alerts.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../helpers/fake_reminder_scheduler.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
final today = DateTime(2026, 10, 11, 10);

Future<void> setBudget(AppDatabase db, int amount) =>
    BudgetsRepository(db).setBudget(month: DateTime(2026, 10), amount: amount);

Future<void> spend(
  AppDatabase db,
  Basics b,
  int amount, {
  DateTime? date,
  int? category,
}) => addTransaction(
  db,
  type: TransactionType.expense,
  amount: amount,
  accountId: b.cash,
  categoryId: category ?? b.food,
  date: date ?? today,
);

Future<void> preference(AppDatabase db, String key, String value) =>
    db.settingsDao.put(key, value);

/// Opens the app with a fake scheduler and gives it a moment.
Future<FakeReminderScheduler> start(WidgetTester tester, AppDatabase db) async {
  final scheduler = FakeReminderScheduler();
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
  );
  return scheduler;
}

/// Writes an expense while the app runs, then lets the alerts react.
Future<void> spendNow(
  WidgetTester tester,
  AppDatabase db,
  Basics b,
  int amount, {
  DateTime? date,
  int? category,
}) async {
  await spend(db, b, amount, date: date, category: category);
  await tester.pumpAndSettle();
}

void main() {
  group('the budget alert', () {
    testWithDatabase('comes when an expense takes the budget past 85%', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 880000);

      expect(scheduler.shown.single.kind, AlertKind.budgetNear);
      expect(scheduler.shown.single.body, contains('88%'));
    });

    testWithDatabase('is kept in the notification history', (tester, db) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      await start(tester, db);

      await spendNow(tester, db, b, 880000);

      final logged = await db.notificationLogDao.getAll();
      expect(logged.where((r) => r.immediate).map((r) => r.kind), [
        AlertKind.budgetNear,
      ]);
    });

    testWithDatabase('comes once for each step, then stays quiet', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 880000);
      await spendNow(tester, db, b, 10000);
      await spendNow(tester, db, b, 200000);
      await spendNow(tester, db, b, 50000);

      expect(scheduler.shown.map((r) => r.kind), [
        AlertKind.budgetNear,
        AlertKind.budgetOver,
      ]);
      expect(scheduler.shown.last.body, contains('৳900.00'));
    });

    testWithDatabase('goes straight to "crossed" when one expense does both', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 1500000);

      expect(scheduler.shown.map((r) => r.kind), [AlertKind.budgetOver]);
    });

    testWithDatabase('does not come for what was written before the app', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      await spend(db, b, 950000);

      final scheduler = await start(tester, db);

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('does not come without a budget', (tester, db) async {
      final b = await seedBasics(db);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 5000000);

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('does not come for income', (tester, db) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      await spend(db, b, 900000);
      final scheduler = await start(tester, db);

      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 100000,
        accountId: b.cash,
        categoryId: b.salary,
        date: today,
      );
      await tester.pumpAndSettle();

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('can be switched off', (tester, db) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      await preference(db, PreferenceKeys.budgetAlerts, 'false');
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 950000);

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('uses the phone\'s sound when funny sounds are off', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, 1000000);
      await preference(db, PreferenceKeys.funSounds, 'false');
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 950000);

      expect(scheduler.shown, hasLength(1));
      expect(scheduler.funSounds, isFalse);
    });
  });

  group('the habit alert', () {
    Future<void> fourRickshaws(AppDatabase db, Basics b) async {
      for (var day = 7; day <= 10; day++) {
        await spend(
          db,
          b,
          5000,
          date: DateTime(2026, 10, day, 9),
          category: b.transport,
        );
      }
    }

    testWithDatabase('comes with the fifth expense of a kind in a week', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await fourRickshaws(db, b);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 5000, category: b.transport);

      final alert = scheduler.shown.single;
      expect(alert.kind, AlertKind.habit);
      expect(alert.title, 'Transport again?');
      expect(alert.body, contains('5 times'));
      expect(alert.body, contains('৳250.00'));
    });

    testWithDatabase('does not come for the fourth or the sixth', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      final scheduler = await start(tester, db);

      for (var day = 6; day <= 11; day++) {
        await spendNow(
          tester,
          db,
          b,
          5000,
          date: DateTime(2026, 10, day, 9),
          category: b.transport,
        );
      }

      // Six expenses in all: only the fifth was worth a word.
      expect(scheduler.shown, hasLength(1));
    });

    testWithDatabase('counts only the last seven days', (tester, db) async {
      final b = await seedBasics(db);
      for (var day = 1; day <= 4; day++) {
        await spend(
          db,
          b,
          5000,
          date: DateTime(2026, 10, day, 9),
          category: b.transport,
        );
      }
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 5000, category: b.transport);

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('keeps the kinds of spending apart', (tester, db) async {
      final b = await seedBasics(db);
      await fourRickshaws(db, b);
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 5000, category: b.food);

      expect(scheduler.shown, isEmpty);
    });

    testWithDatabase('can be switched off', (tester, db) async {
      final b = await seedBasics(db);
      await fourRickshaws(db, b);
      await preference(db, PreferenceKeys.habitAlerts, 'false');
      final scheduler = await start(tester, db);

      await spendNow(tester, db, b, 5000, category: b.transport);

      expect(scheduler.shown, isEmpty);
    });
  });

  group('the daily reminder', () {
    testWithDatabase('is not scheduled until it is switched on', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      final scheduler = await start(tester, db);

      expect(
        scheduler.scheduled.where((r) => r.kind == AlertKind.daily),
        isEmpty,
      );
    });

    testWithDatabase('is scheduled for the evenings once switched on', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await preference(db, PreferenceKeys.dailyReminder, 'true');
      await preference(db, PreferenceKeys.dailyReminderMinutes, '1230');

      final scheduler = await start(tester, db);

      final daily = scheduler.scheduled.where((r) => r.kind == AlertKind.daily);
      expect(daily, hasLength(dailyReminderDays));
      expect(daily.first.when, DateTime(2026, 10, 11, 20, 30));
    });

    testWithDatabase('skips today when something was already written', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await spend(db, b, 5000);
      await preference(db, PreferenceKeys.dailyReminder, 'true');

      final scheduler = await start(tester, db);

      final daily = scheduler.scheduled.where((r) => r.kind == AlertKind.daily);
      expect(daily.first.when, DateTime(2026, 10, 12, 21));
    });

    testWithDatabase('is taken off once an entry is written today', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await preference(db, PreferenceKeys.dailyReminder, 'true');
      final scheduler = await start(tester, db);
      expect(scheduler.cancelled, isEmpty);

      await spendNow(tester, db, b, 5000);

      expect(scheduler.cancelled, contains(dailyReminderId(testNow)));
    });
  });

  group('the wrapped alert', () {
    testWithDatabase('is scheduled for the 28th once the month has entries', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await spend(db, b, 5000);

      final scheduler = await start(tester, db);

      final wrapped = scheduler.scheduled.where(
        (r) => r.kind == AlertKind.wrapped,
      );
      expect(wrapped.single.when, DateTime(2026, 10, 28, 9));
    });

    testWithDatabase('is not scheduled when it is switched off', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await spend(db, b, 5000);
      await preference(db, PreferenceKeys.wrappedAlert, 'false');

      final scheduler = await start(tester, db);

      expect(
        scheduler.scheduled.where((r) => r.kind == AlertKind.wrapped),
        isEmpty,
      );
    });
  });

  testWithDatabase('the sound choice reaches the scheduler', (
    tester,
    db,
  ) async {
    await seedBasics(db);
    await preference(db, PreferenceKeys.funSounds, 'false');

    final scheduler = await start(tester, db);

    expect(scheduler.funSounds, isFalse);
  });
}
