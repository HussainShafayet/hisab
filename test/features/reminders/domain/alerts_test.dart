import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/features/reminders/domain/alerts.dart';

// Sunday 11 October 2026, 2:30 pm.
final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  group('the daily reminder', () {
    test('comes every evening for a week, at the chosen time', () {
      final reminders = dailyRemindersFor(
        now: now,
        minutes: 21 * 60 + 15,
        writtenToday: false,
      );

      expect(reminders, hasLength(dailyReminderDays));
      expect(reminders.first.when, DateTime(2026, 10, 11, 21, 15));
      expect(reminders.last.when, DateTime(2026, 10, 17, 21, 15));
      expect(reminders.every((r) => r.kind == AlertKind.daily), isTrue);
    });

    test('leaves out today when something was already written', () {
      final reminders = dailyRemindersFor(
        now: now,
        minutes: 21 * 60,
        writtenToday: true,
      );

      expect(reminders, hasLength(dailyReminderDays - 1));
      expect(reminders.first.when, DateTime(2026, 10, 12, 21));
    });

    test('leaves out today when the time has already passed', () {
      final reminders = dailyRemindersFor(
        now: now,
        minutes: 9 * 60,
        writtenToday: false,
      );

      expect(reminders.first.when, DateTime(2026, 10, 12, 9));
    });

    test('has a different id for each day, and says something different', () {
      final reminders = dailyRemindersFor(
        now: now,
        minutes: 21 * 60,
        writtenToday: false,
      );

      expect(reminders.map((r) => r.id).toSet(), hasLength(reminders.length));
      expect(reminders.first.id, dailyReminderId(now));
      expect(reminders.map((r) => r.body).toSet().length, greaterThan(3));
    });

    test('crosses into the next month', () {
      final reminders = dailyRemindersFor(
        now: DateTime(2026, 10, 29, 10),
        minutes: 21 * 60,
        writtenToday: false,
      );

      expect(reminders.last.when, DateTime(2026, 11, 4, 21));
    });
  });

  group('the wrapped alert', () {
    test('comes at 9 on the first day it is on offer', () {
      final reminders = wrappedReminderFor(now, hasEntries: true);

      // October has 31 days: the last four are the 28th to the 31st.
      expect(reminders.single.when, DateTime(2026, 10, 28, 9));
      expect(reminders.single.kind, AlertKind.wrapped);
      expect(reminders.single.title, 'Your October 2026 wrapped is ready');
    });

    test('does not come when nothing was written this month', () {
      expect(wrappedReminderFor(now, hasEntries: false), isEmpty);
    });

    test('does not come once the moment has passed', () {
      expect(
        wrappedReminderFor(DateTime(2026, 10, 28, 10), hasEntries: true),
        isEmpty,
      );
      expect(
        wrappedReminderFor(DateTime(2026, 10, 30), hasEntries: true),
        isEmpty,
      );
    });
  });

  group('the budget alert', () {
    test('has a step: nothing, nearly used at 85, crossed at 100', () {
      expect(budgetStepOf(0), BudgetStep.none);
      expect(budgetStepOf(84), BudgetStep.none);
      expect(budgetStepOf(85), BudgetStep.near);
      expect(budgetStepOf(99), BudgetStep.near);
      expect(budgetStepOf(100), BudgetStep.over);
      expect(budgetStepOf(140), BudgetStep.over);
    });

    test('says how much is gone, or how far over', () {
      final near = budgetAlertFor(
        BudgetStep.near,
        percent: 88,
        overBy: -1200,
        now: now,
      )!;
      final over = budgetAlertFor(
        BudgetStep.over,
        percent: 112,
        overBy: 500000,
        now: now,
      )!;

      expect(near.kind, AlertKind.budgetNear);
      expect(near.body, contains('88%'));
      expect(over.kind, AlertKind.budgetOver);
      expect(over.body, contains('৳5,000.00'));
      expect(near.id, isNot(over.id));
      expect(
        budgetAlertFor(BudgetStep.none, percent: 10, overBy: 0, now: now),
        isNull,
      );
    });
  });

  group('the habit alert', () {
    test('is for every fifth expense of a kind in a week', () {
      expect(
        [for (var n = 0; n <= 11; n++) isHabit(n)],
        [
          false, false, false, false, false, // 0 to 4
          true, false, false, false, false, // 5 to 9
          true, false, // 10 and 11
        ],
      );
    });

    test('names the category, the count and the total', () {
      final alert = habitAlertFor(
        categoryId: 7,
        category: 'Rickshaw',
        count: 5,
        total: 25000,
        now: now,
      );

      expect(alert.kind, AlertKind.habit);
      expect(alert.title, 'Rickshaw again?');
      expect(alert.body, contains('5 times'));
      expect(alert.body, contains('৳250.00'));
    });

    test('has its own id for each category', () {
      int idOf(int category) => habitAlertFor(
        categoryId: category,
        category: 'X',
        count: 5,
        total: 1,
        now: now,
      ).id;

      expect(idOf(1), isNot(idOf(2)));
    });
  });

  group('the kinds', () {
    test('each have a channel and a sound, and the channels differ', () {
      expect(AlertKind.values.map((k) => k.channelId).toSet(), hasLength(8));
      for (final kind in AlertKind.values) {
        expect(kind.sound, startsWith('alert_'));
        expect(kind.label, isNotEmpty);
      }
    });
  });
}
