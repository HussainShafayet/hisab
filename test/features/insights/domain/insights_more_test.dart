import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/insights/domain/insights.dart';

// Sunday 25 October 2026: the 25th day of a month with 31 days.
final today = DateTime(2026, 10, 25);

InsightInput input({
  int expense = 0,
  int income = 0,
  int daysSoFar = 25,
  int noSpendDays = 0,
  List<int> weekdaySpend = const [],
  BiggestExpense? biggest,
  int smallCount = 0,
  int smallTotal = 0,
  int regret = 0,
  UpcomingLoan? loan,
}) => InsightInput(
  today: today,
  expense: expense,
  expenseLastPeriod: 0,
  categories: const [],
  categoriesLastPeriod: const [],
  income: income,
  daysSoFar: daysSoFar,
  noSpendDays: noSpendDays,
  weekdaySpend: weekdaySpend,
  biggestExpense: biggest,
  smallSpendCount: smallCount,
  smallSpendTotal: smallTotal,
  regretTotal: regret,
  loan: loan,
);

List<InsightKind> kinds(List<Insight> list) => [for (final i in list) i.kind];

void main() {
  group('days with no spending', () {
    test('are mentioned from three of them', () {
      expect(
        kinds(buildInsights(input(noSpendDays: 3))),
        contains(InsightKind.noSpendDays),
      );
      expect(
        kinds(buildInsights(input(noSpendDays: 2))),
        isNot(contains(InsightKind.noSpendDays)),
      );
    });

    test('wait for the first days to pass', () {
      expect(
        kinds(buildInsights(input(noSpendDays: 3, daysSoFar: 4))),
        isEmpty,
      );
    });
  });

  group('the busy weekday', () {
    test('is named when it takes 30% or more', () {
      final result = buildInsights(
        input(expense: 1000000, weekdaySpend: [0, 0, 0, 0, 0, 450000, 550000]),
      );
      final insight = result.firstWhere(
        (i) => i.kind == InsightKind.busyWeekday,
      );
      expect(insight.args['weekday'], 6);
      expect(insight.args['percent'], 55);
    });

    test('is not named when the spending is even', () {
      final result = buildInsights(
        input(expense: 1400000, weekdaySpend: List.filled(7, 200000)),
      );
      expect(kinds(result), isNot(contains(InsightKind.busyWeekday)));
    });
  });

  group('the biggest expense', () {
    test('is mentioned when it is a fifth of the month and ৳1,000 or more', () {
      final result = buildInsights(
        input(
          expense: 500000,
          biggest: const BiggestExpense(id: 9, amount: 200000, label: 'Rent'),
        ),
      );
      final insight = result.firstWhere(
        (i) => i.kind == InsightKind.biggestExpense,
      );
      expect(insight.link, InsightLink.transaction);
      expect(insight.targetId, 9);
    });

    test('is left alone when it is small next to the month', () {
      final result = buildInsights(
        input(
          expense: 5000000,
          biggest: const BiggestExpense(id: 9, amount: 200000, label: 'Rent'),
        ),
      );
      expect(kinds(result), isNot(contains(InsightKind.biggestExpense)));
    });
  });

  group('income kept or overspent', () {
    test('praises keeping a fifth or more', () {
      final result = buildInsights(input(income: 5000000, expense: 3000000));
      final insight = result.firstWhere(
        (i) => i.kind == InsightKind.savingsKept,
      );
      expect(insight.args['percent'], 40);
      expect(insight.tone, InsightTone.good);
    });

    test('warns when more was spent than earned', () {
      final result = buildInsights(input(income: 1000000, expense: 1300000));
      final insight = result.firstWhere(
        (i) => i.kind == InsightKind.spentMoreThanEarned,
      );
      expect(insight.args['amount'], 300000);
      expect(insight.tone, InsightTone.warning);
    });

    test('says nothing without income', () {
      expect(kinds(buildInsights(input(expense: 1000000))), isEmpty);
    });
  });

  test('many small spends are added up', () {
    final result = buildInsights(input(smallCount: 12, smallTotal: 90000));
    expect(kinds(result), contains(InsightKind.smallSpends));
    expect(
      kinds(buildInsights(input(smallCount: 12, smallTotal: 20000))),
      isEmpty,
    );
  });

  test('regret is called out from 15% of the spending', () {
    expect(
      kinds(buildInsights(input(expense: 1000000, regret: 150000))),
      contains(InsightKind.regretShare),
    );
    expect(
      kinds(buildInsights(input(expense: 1000000, regret: 100000))),
      isNot(contains(InsightKind.regretShare)),
    );
  });

  group('a loan about to fall due', () {
    test('is named by whether it is to get or to pay', () {
      final get = buildInsights(
        input(
          loan: const UpcomingLoan(
            person: 'Rahim',
            amount: 50000,
            days: 3,
            lent: true,
          ),
        ),
      );
      final pay = buildInsights(
        input(
          loan: const UpcomingLoan(
            person: 'Karim',
            amount: 50000,
            days: 0,
            lent: false,
          ),
        ),
      );
      expect(kinds(get), [InsightKind.loanToGet]);
      expect(kinds(pay), [InsightKind.loanToPay]);
      expect(get.single.link, InsightLink.loans);
    });

    test('waits until it is within a week', () {
      final result = buildInsights(
        input(
          loan: const UpcomingLoan(
            person: 'Rahim',
            amount: 50000,
            days: 20,
            lent: true,
          ),
        ),
      );
      expect(result, isEmpty);
    });
  });

  test(
    'warnings come before good news and facts, and at most max are kept',
    () {
      final result = buildInsights(
        input(
          income: 1000000,
          expense: 1300000,
          noSpendDays: 4,
          smallCount: 12,
          smallTotal: 90000,
        ),
        max: 2,
      );
      expect(result, hasLength(2));
      expect(result.first.tone, InsightTone.warning);
    },
  );
}
