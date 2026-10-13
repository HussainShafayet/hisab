import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/safe_to_spend.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

// Sunday 11 October 2026: 21 days to the end of the month, today included.
final today = DateTime(2026, 10, 11, 14, 30);

RecurringRule rule({
  required DateTime due,
  int amount = 500000,
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  TransactionType type = TransactionType.expense,
  bool paused = false,
  DateTime? end,
}) => RecurringRule(
  id: 1,
  title: 'Rent',
  type: type,
  amount: amount,
  accountId: 1,
  categoryId: 1,
  frequency: frequency,
  startDate: due,
  nextDue: due,
  endDate: end,
  autoAdd: false,
  remind: true,
  isPaused: paused,
);

void main() {
  group('upcomingBillsThisMonth', () {
    test('counts a monthly expense due later this month once', () {
      final rules = [rule(due: DateTime(2026, 10, 20))];

      expect(upcomingBillsThisMonth(rules, today), 500000);
    });

    test('counts every week of a weekly one that is left', () {
      // 13, 20 and 27 October.
      final rules = [
        rule(
          due: DateTime(2026, 10, 13),
          amount: 100000,
          frequency: RecurrenceFrequency.weekly,
        ),
      ];

      expect(upcomingBillsThisMonth(rules, today), 300000);
    });

    test('counts a day that is due but not added yet', () {
      final rules = [rule(due: DateTime(2026, 10, 5))];

      expect(upcomingBillsThisMonth(rules, today), 500000);
    });

    test('leaves out next month, income, paused and ended ones', () {
      final rules = [
        rule(due: DateTime(2026, 11, 2)),
        rule(due: DateTime(2026, 10, 20), type: TransactionType.income),
        rule(due: DateTime(2026, 10, 20), paused: true),
        rule(due: DateTime(2026, 10, 20), end: DateTime(2026, 10, 15)),
      ];

      expect(upcomingBillsThisMonth(rules, today), 0);
    });

    test('stops at the end date within the month', () {
      final rules = [
        rule(
          due: DateTime(2026, 10, 13),
          amount: 100000,
          frequency: RecurrenceFrequency.weekly,
          end: DateTime(2026, 10, 15),
        ),
      ];

      expect(upcomingBillsThisMonth(rules, today), 100000);
    });
  });

  group('safeToSpendOf', () {
    SafeToSpend? figures({
      int? budget = 3150000,
      int spentThisMonth = 1090000,
      int spentToday = 40000,
      List<RecurringRule> rules = const [],
      DateTime? on,
    }) => safeToSpendOf(
      budget: budget,
      spentThisMonth: spentThisMonth,
      spentToday: spentToday,
      rules: rules,
      today: on ?? today,
    );

    test('shares what is left over the days that are left', () {
      final safe = figures()!;

      expect(safe.spentBeforeToday, 1050000);
      expect(safe.daysLeft, 21);
      expect(safe.remaining, 2100000);
      expect(safe.perDay, 100000);
      expect(safe.leftToday, 60000);
      expect(safe.isOverToday, isFalse);
      expect(safe.isUsedUp, isFalse);
      expect(safe.usedToday, closeTo(0.4, 0.0001));
    });

    test('takes the bills still to come off first', () {
      // ৳5,000 of rent leaves ৳16,000 for 21 days.
      final safe = figures(rules: [rule(due: DateTime(2026, 10, 20))])!;

      expect(safe.upcomingBills, 500000);
      expect(safe.remaining, 1600000);
      expect(safe.perDay, 1600000 ~/ 21);
    });

    test('goes below zero once today is overspent', () {
      final safe = figures(spentThisMonth: 1180000, spentToday: 130000)!;

      expect(safe.leftToday, -30000);
      expect(safe.isOverToday, isTrue);
      expect(safe.usedToday, 1.0);
    });

    test('has nothing to spend when the budget is used up', () {
      final safe = figures(spentThisMonth: 3300000, spentToday: 0)!;

      expect(safe.remaining, -150000);
      expect(safe.isUsedUp, isTrue);
      expect(safe.perDay, 0);
      expect(safe.isOverToday, isFalse);
    });

    test('has nothing to spend when the bills take what is left', () {
      final safe = figures(
        rules: [rule(due: DateTime(2026, 10, 20), amount: 2100000)],
      )!;

      expect(safe.isUsedUp, isTrue);
    });

    test('on the last day of the month all of what is left is for today', () {
      final safe = figures(on: DateTime(2026, 10, 31, 9))!;

      expect(safe.daysLeft, 1);
      expect(safe.perDay, safe.remaining);
    });

    test('is null without a budget', () {
      expect(figures(budget: null), isNull);
      expect(figures(budget: 0), isNull);
    });
  });
}
