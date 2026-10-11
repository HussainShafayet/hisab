import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_progress.dart';

BudgetProgress progress(int limit, int spent) =>
    BudgetProgress(limit: limit, spent: spent);

void main() {
  group('BudgetProgress', () {
    test('is ok while under 80%', () {
      expect(progress(1000, 0).level, BudgetLevel.ok);
      expect(progress(1000, 500).level, BudgetLevel.ok);
      expect(progress(1000, 799).level, BudgetLevel.ok);
    });

    test('warns from 80% up to 100%', () {
      expect(progress(1000, 800).level, BudgetLevel.warning);
      expect(progress(1000, 950).level, BudgetLevel.warning);
      expect(progress(1000, 999).level, BudgetLevel.warning);
    });

    test('is over at 100% and above', () {
      expect(progress(1000, 1000).level, BudgetLevel.over);
      expect(progress(1000, 1001).level, BudgetLevel.over);
      expect(progress(1000, 5000).level, BudgetLevel.over);
    });

    test('the level changes exactly where the percent reaches 80 and 100', () {
      // 79.99% must not be called 80%, or show a warning.
      final almost = progress(100000, 79999);
      expect(almost.percent, 79);
      expect(almost.level, BudgetLevel.ok);
      final at = progress(100000, 80000);
      expect(at.percent, 80);
      expect(at.level, BudgetLevel.warning);
      expect(progress(100000, 99999).percent, 99);
      expect(progress(100000, 100000).percent, 100);
    });

    test('percent is rounded down and can go above 100', () {
      expect(progress(3, 1).percent, 33);
      expect(progress(3, 2).percent, 66);
      expect(progress(1000, 2500).percent, 250);
    });

    test('remaining is the limit minus what was spent, negative when over', () {
      expect(progress(1000, 250).remaining, 750);
      expect(progress(1000, 1000).remaining, 0);
      expect(progress(1000, 1300).remaining, -300);
    });

    test('fraction is for drawing a bar and stays between 0 and 1', () {
      expect(progress(1000, 0).fraction, 0);
      expect(progress(1000, 250).fraction, 0.25);
      expect(progress(1000, 1000).fraction, 1);
      expect(progress(1000, 9000).fraction, 1);
    });

    test('works with very large amounts', () {
      const big = 99999999999999; // 999,999,999,999.99 BDT
      expect(progress(big, big).percent, 100);
      expect(progress(big, big ~/ 2).percent, 49);
    });

    test('does not divide by a zero limit', () {
      expect(progress(0, 100).percent, 0);
      expect(progress(0, 100).fraction, 0);
    });
  });

  group('daysLeftInMonth', () {
    final today = DateTime(2026, 10, 11, 14, 30);

    test('counts today in the current month', () {
      expect(daysLeftInMonth(DateTime(2026, 10), today), 21);
      expect(daysLeftInMonth(DateTime(2026, 10, 25), today), 21);
    });

    test('is every day on the 1st and one on the last day', () {
      expect(daysLeftInMonth(DateTime(2026, 10), DateTime(2026, 10, 1)), 31);
      expect(daysLeftInMonth(DateTime(2026, 10), DateTime(2026, 10, 31)), 1);
    });

    test('is every day of a future month', () {
      expect(daysLeftInMonth(DateTime(2026, 11), today), 30);
      expect(daysLeftInMonth(DateTime(2027, 2), today), 28);
    });

    test('is null for a month that is over', () {
      expect(daysLeftInMonth(DateTime(2026, 9), today), isNull);
      expect(daysLeftInMonth(DateTime(2025, 12), today), isNull);
    });

    test('knows February in a leap year', () {
      expect(daysLeftInMonth(DateTime(2028, 2), DateTime(2028, 2, 10)), 20);
    });
  });

  group('remainingPerDay', () {
    final today = DateTime(2026, 10, 11);

    test('divides what is left by the days left', () {
      expect(
        remainingPerDay(
          remaining: 210000,
          month: DateTime(2026, 10),
          today: today,
        ),
        10000, // 21 days left
      );
    });

    test('rounds down to a whole poisha', () {
      expect(
        remainingPerDay(
          remaining: 100,
          month: DateTime(2026, 10),
          today: DateTime(2026, 10, 29),
        ),
        33, // 3 days left
      );
    });

    test('is zero when nothing is left or the budget is exceeded', () {
      expect(
        remainingPerDay(remaining: 0, month: DateTime(2026, 10), today: today),
        0,
      );
      expect(
        remainingPerDay(
          remaining: -500,
          month: DateTime(2026, 10),
          today: today,
        ),
        0,
      );
    });

    test('uses the whole month for a future month', () {
      expect(
        remainingPerDay(
          remaining: 300000,
          month: DateTime(2026, 11),
          today: today,
        ),
        10000, // 30 days
      );
    });

    test('is null for a month that is over', () {
      expect(
        remainingPerDay(
          remaining: 300000,
          month: DateTime(2026, 9),
          today: today,
        ),
        isNull,
      );
    });
  });
}
