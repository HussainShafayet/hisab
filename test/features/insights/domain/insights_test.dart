import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/reports/domain/category_total.dart';

CategoryTotal category(int id, String name, int total) => CategoryTotal(
  categoryId: id,
  name: name,
  icon: 'category',
  color: 0xFF000000,
  total: total,
);

// Sunday 11 October 2026: the 11th day of a month with 31 days.
final today = DateTime(2026, 10, 11);

InsightInput input({
  int expense = 0,
  int last = 0,
  List<CategoryTotal> categories = const [],
  List<CategoryTotal> lastCategories = const [],
  int? limit,
  int spent = 0,
  DebtTotals loans = const DebtTotals(),
  UpcomingRecurring? recurring,
  DateTime? now,
}) => InsightInput(
  today: now ?? today,
  expense: expense,
  expenseLastPeriod: last,
  categories: categories,
  categoriesLastPeriod: lastCategories,
  budgetLimit: limit,
  budgetSpent: spent,
  loans: loans,
  recurring: recurring,
);

List<InsightKind> kinds(List<Insight> list) => [for (final i in list) i.kind];

void main() {
  test('has nothing to say with no data', () {
    expect(buildInsights(input()), isEmpty);
  });

  group('spending against the same days of last month', () {
    test('more is a warning with the percent', () {
      final list = buildInsights(input(expense: 150000, last: 100000));

      expect(kinds(list), [InsightKind.spendingUp]);
      expect(list.single.tone, InsightTone.warning);
      expect(list.single.args['percent'], 50);
    });

    test('less is good news', () {
      final list = buildInsights(input(expense: 60000, last: 100000));

      expect(kinds(list), [InsightKind.spendingDown]);
      expect(list.single.tone, InsightTone.good);
      expect(list.single.args['percent'], 40);
    });

    test('a small change says nothing', () {
      expect(buildInsights(input(expense: 105000, last: 100000)), isEmpty);
      expect(buildInsights(input(expense: 95000, last: 100000)), isEmpty);
    });

    test('exactly the threshold counts', () {
      expect(kinds(buildInsights(input(expense: 110000, last: 100000))), [
        InsightKind.spendingUp,
      ]);
      expect(kinds(buildInsights(input(expense: 90000, last: 100000))), [
        InsightKind.spendingDown,
      ]);
    });

    test(
      'says nothing without spending or without something to compare with',
      () {
        expect(buildInsights(input(expense: 0, last: 100000)), isEmpty);
        expect(buildInsights(input(expense: 100000, last: 0)), isEmpty);
      },
    );
  });

  group('the pace of the budget', () {
    test('over: at this rate the month ends above the limit', () {
      // 40,000 in 11 days of 31: 112,727 for the month.
      final list = buildInsights(input(limit: 100000, spent: 40000));

      expect(kinds(list), [InsightKind.overBudgetPace]);
      expect(list.single.args['projected'], 112727);
      expect(list.single.args['limit'], 100000);
    });

    test('within: at this rate the month ends below the limit', () {
      final list = buildInsights(input(limit: 100000, spent: 20000));

      expect(kinds(list), [InsightKind.withinBudgetPace]);
      expect(list.single.tone, InsightTone.good);
      expect(list.single.args['projected'], 56363);
    });

    test(
      'is left out in the first days, without a budget or without spending',
      () {
        expect(
          buildInsights(
            input(limit: 100000, spent: 50000, now: DateTime(2026, 10, 2)),
          ),
          isEmpty,
        );
        expect(buildInsights(input(spent: 50000)), isEmpty);
        expect(buildInsights(input(limit: 100000, spent: 0)), isEmpty);
        expect(buildInsights(input(limit: 0, spent: 5)), isEmpty);
      },
    );
  });

  group('a category that jumped', () {
    test('names the one that grew most, and by how much', () {
      final list = buildInsights(
        input(
          categories: [
            category(1, 'Food', 300000),
            category(2, 'Transport', 120000),
          ],
          lastCategories: [
            category(1, 'Food', 200000),
            category(2, 'Transport', 50000),
          ],
        ),
      );

      final jump = list.firstWhere((i) => i.kind == InsightKind.categoryJump);
      expect(jump.args['name'], 'Food');
      expect(jump.args['amount'], 100000);
    });

    test('needs a real rise: at least ৳500 and a quarter more', () {
      // +৳400: too small. +10%: too little.
      expect(
        buildInsights(
          input(
            categories: [category(1, 'Food', 90000)],
            lastCategories: [category(1, 'Food', 50000)],
          ),
        ).where((i) => i.kind == InsightKind.categoryJump),
        isEmpty,
      );
      expect(
        buildInsights(
          input(
            categories: [category(1, 'Food', 1100000)],
            lastCategories: [category(1, 'Food', 1000000)],
          ),
        ).where((i) => i.kind == InsightKind.categoryJump),
        isEmpty,
      );
    });

    test('ignores a category that was not there before', () {
      expect(
        buildInsights(input(categories: [category(1, 'New', 500000)]))
            .where((i) => i.kind == InsightKind.categoryJump),
        isEmpty,
      );
    });
  });

  group('the biggest slice', () {
    test('is named when it is a third or more of the spending', () {
      final list = buildInsights(
        input(
          expense: 100000,
          categories: [category(1, 'Food', 40000), category(2, 'Rent', 30000)],
        ),
      );

      final top = list.single;
      expect(top.kind, InsightKind.topCategory);
      expect(top.args['name'], 'Food');
      expect(top.args['percent'], 40);
    });

    test('is left out when it is a small share', () {
      expect(
        buildInsights(
          input(expense: 100000, categories: [category(1, 'Food', 20000)]),
        ),
        isEmpty,
      );
    });
  });

  group('loans', () {
    test('overdue loans are a warning', () {
      final list = buildInsights(
        input(loans: const DebtTotals(overdueCount: 2)),
      );

      expect(list.single.kind, InsightKind.loansOverdue);
      expect(list.single.tone, InsightTone.warning);
      expect(list.single.args['count'], 2);
    });

    test('what is owed either way is a plain fact', () {
      final list = buildInsights(
        input(loans: const DebtTotals(toReceive: 50000, toPay: 20000)),
      );

      expect(kinds(list), [InsightKind.loansToGet, InsightKind.loansToPay]);
      expect(list.first.args['amount'], 50000);
      expect(list.last.args['amount'], 20000);
    });

    test('no loans says nothing', () {
      expect(buildInsights(input(loans: const DebtTotals())), isEmpty);
    });
  });

  group('recurring', () {
    test('mentions an item due within a week', () {
      final list = buildInsights(
        input(recurring: const UpcomingRecurring(title: 'Rent', days: 3)),
      );

      expect(list.single.kind, InsightKind.recurringSoon);
      expect(list.single.args['title'], 'Rent');
      expect(list.single.args['days'], 3);
    });

    test('includes today and the seventh day, not the eighth', () {
      expect(
        buildInsights(
          input(recurring: const UpcomingRecurring(title: 'A', days: 0)),
        ),
        isNotEmpty,
      );
      expect(
        buildInsights(
          input(recurring: const UpcomingRecurring(title: 'A', days: 7)),
        ),
        isNotEmpty,
      );
      expect(
        buildInsights(
          input(recurring: const UpcomingRecurring(title: 'A', days: 8)),
        ),
        isEmpty,
      );
    });
  });

  group('order and number', () {
    final busy = input(
      expense: 150000,
      last: 100000,
      limit: 100000,
      spent: 20000,
      categories: [category(1, 'Food', 100000)],
      loans: const DebtTotals(toReceive: 1000, overdueCount: 1),
      recurring: const UpcomingRecurring(title: 'Rent', days: 2),
    );

    test('warnings come first, then good news, then facts', () {
      final list = buildInsights(busy, max: 10);

      expect(kinds(list), [
        InsightKind.spendingUp,
        InsightKind.loansOverdue,
        InsightKind.withinBudgetPace,
        InsightKind.topCategory,
        InsightKind.loansToGet,
        InsightKind.recurringSoon,
      ]);
    });

    test('is limited to four unless asked for more', () {
      expect(buildInsights(busy).length, 4);
      expect(buildInsights(busy, max: 2).length, 2);
      expect(buildInsights(busy, max: 2).first.kind, InsightKind.spendingUp);
    });
  });
}
