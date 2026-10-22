import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/domain/year_facts.dart';

MonthTotals month(int number, {int income = 0, int expense = 0}) => MonthTotals(
  month: DateTime(2026, number),
  totals: PeriodTotals(income: income, expense: expense),
);

void main() {
  final now = DateTime(2026, 10, 11);

  test('averages over the months that have entries', () {
    final months = [
      month(8, income: 100000, expense: 60000),
      month(9, income: 300000, expense: 120000),
      month(10, income: 200000, expense: 90000),
    ];

    final facts = yearFacts(months, now: now);

    expect(facts.activeMonths, 3);
    expect(facts.averageIncome, 200000);
    expect(facts.averageExpense, 90000);
  });

  test('a month with nothing in it does not pull the average down', () {
    final months = [
      for (var m = 1; m <= 12; m++)
        if (m == 9) month(9, income: 90000, expense: 30000) else month(m),
    ];

    final facts = yearFacts(months, now: now);

    expect(facts.activeMonths, 1);
    expect(facts.averageExpense, 30000);
  });

  test('a month after today is left out', () {
    final months = [
      month(10, expense: 10000),
      month(11, expense: 900000),
      month(12, expense: 900000),
    ];

    final facts = yearFacts(months, now: now);

    expect(facts.activeMonths, 1);
    expect(facts.mostSpent!.month, DateTime(2026, 10));
  });

  test('finds the month with the most spent and the most kept', () {
    final months = [
      month(7, income: 100000, expense: 90000),
      month(8, income: 100000, expense: 140000),
      month(9, income: 300000, expense: 100000),
    ];

    final facts = yearFacts(months, now: now);

    expect(facts.mostSpent!.month, DateTime(2026, 8));
    // September kept 2,000; July kept 100; August kept nothing.
    expect(facts.mostKept!.month, DateTime(2026, 9));
  });

  test('no month kept anything when every one spent more than it earned', () {
    final facts = yearFacts([
      month(9, income: 10000, expense: 20000),
      month(10, expense: 5000),
    ], now: now);

    expect(facts.mostKept, isNull);
    expect(facts.mostSpent, isNotNull);
  });

  test('a year with no entries has no facts', () {
    final facts = yearFacts([for (var m = 1; m <= 12; m++) month(m)], now: now);

    expect(facts.activeMonths, 0);
    expect(facts.averageIncome, 0);
    expect(facts.averageExpense, 0);
    expect(facts.mostSpent, isNull);
    expect(facts.mostKept, isNull);
  });
}
