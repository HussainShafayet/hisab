import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_progress.dart';

// October has 31 days.
final month = DateTime(2026, 10);

BudgetPace? pace(int spent, {int limit = 100000, int day = 16}) => budgetPace(
  limit: limit,
  spent: spent,
  month: month,
  today: DateTime(2026, 10, day),
);

void main() {
  test(
    'is on track when the share used matches the share of the month gone',
    () {
      // 16 of 31 days is 52%.
      expect(pace(50000), BudgetPace.onTrack);
      expect(pace(45000), BudgetPace.onTrack);
      expect(pace(60000), BudgetPace.onTrack);
    },
  );

  test('is fast when more than ten points ahead', () {
    expect(pace(63000), BudgetPace.fast);
    expect(pace(100000), BudgetPace.fast);
    expect(pace(150000), BudgetPace.fast);
  });

  test('is slow when more than ten points behind', () {
    expect(pace(41000), BudgetPace.slow);
    expect(pace(0), BudgetPace.slow);
  });

  test('is null in the first two days of the month', () {
    expect(pace(90000, day: 1), isNull);
    expect(pace(90000, day: 2), isNull);
    expect(pace(90000, day: 3), BudgetPace.fast);
  });

  test('is null without a limit', () {
    expect(pace(100, limit: 0), isNull);
  });

  test('is null for a month that is not the current one', () {
    expect(
      budgetPace(
        limit: 100000,
        spent: 100000,
        month: DateTime(2026, 9),
        today: DateTime(2026, 10, 16),
      ),
      isNull,
    );
    expect(
      budgetPace(
        limit: 100000,
        spent: 1,
        month: DateTime(2026, 11),
        today: DateTime(2026, 10, 16),
      ),
      isNull,
    );
  });

  test('uses the length of the month', () {
    // 15 of 28 days is 54%: 54,000 is on track in February.
    expect(
      budgetPace(
        limit: 100000,
        spent: 54000,
        month: DateTime(2027, 2),
        today: DateTime(2027, 2, 15),
      ),
      BudgetPace.onTrack,
    );
  });
}
