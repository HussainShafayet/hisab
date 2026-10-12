import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/reports/presentation/providers/reports_providers.dart';
import 'package:hishab/features/reports/presentation/screens/reports_screen.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Finder inside(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> openReports(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Reports'),
    ),
  );
  await tester.pumpAndSettle();
}

class SeededReports {
  const SeededReports({
    required this.basics,
    required this.rent,
    required this.groceries,
    required this.rentExpense,
    required this.transportExpense,
  });

  final Basics basics;
  final int rent;
  final int groceries;
  final int rentExpense;
  final int transportExpense;
}

/// September: income 30,000 and Food 1,000.
/// October: income 50,000; Food 1,200 + Groceries (a Food sub-category) 300;
/// Transport 500; Rent 8,000. A 99,999 transfer and a 77,777 correction
/// must not count.
Future<SeededReports> seedReports(AppDatabase db) async {
  final b = await seedBasics(db);
  final rent = await insertTestCategory(db, name: 'Rent');
  final groceries = await insertTestCategory(
    db,
    name: 'Groceries',
    parentId: b.food,
  );

  Future<int> add(
    TransactionType type,
    int amount,
    DateTime date, {
    int? category,
    int? toAccount,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: b.cash,
      categoryId: Value(category),
      toAccountId: Value(toAccount),
      date: date,
      isAdjustment: Value(adjustment),
    ),
  );
  const expense = TransactionType.expense;

  await add(
    TransactionType.income,
    3000000,
    DateTime(2026, 9, 1),
    category: b.salary,
  );
  await add(expense, 100000, DateTime(2026, 9, 10), category: b.food);

  await add(
    TransactionType.income,
    5000000,
    DateTime(2026, 10, 1),
    category: b.salary,
  );
  await add(expense, 120000, DateTime(2026, 10, 3), category: b.food);
  await add(expense, 30000, DateTime(2026, 10, 3, 12), category: groceries);
  final rentExpense = await add(
    expense,
    800000,
    DateTime(2026, 10, 4),
    category: rent,
  );
  final transportExpense = await add(
    expense,
    50000,
    DateTime(2026, 10, 7),
    category: b.transport,
  );
  await add(
    TransactionType.transfer,
    9999900,
    DateTime(2026, 10, 8),
    toAccount: b.bkash,
  );
  await add(
    expense,
    7777700,
    DateTime(2026, 10, 9),
    category: b.food,
    adjustment: true,
  );

  return SeededReports(
    basics: b,
    rent: rent,
    groceries: groceries,
    rentExpense: rentExpense,
    transportExpense: transportExpense,
  );
}

void main() {
  group('a month', () {
    testWithDatabase(
      'shows income, expense and balance without transfers and corrections',
      (tester, db) async {
        useTallScreen(tester);
        await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);

        expect(find.text('October 2026'), findsOneWidget);
        expect(inside('report-summary', '৳50,000.00'), findsOneWidget);
        expect(
          inside('report-summary', '৳10,000.00'),
          findsOneWidget,
        ); // 1,200 + 300 + 500 + 8,000
        expect(inside('report-summary', '৳40,000.00'), findsOneWidget);
      },
    );

    testWithDatabase('compares with the month before', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.text('Compared with September 2026'), findsOneWidget);
      // Income 30,000 -> 50,000: up 67%.
      expect(inside('compare-income', '67% · ৳20,000.00'), findsOneWidget);
      // Expense 1,000 -> 10,000: up 900%.
      expect(inside('compare-expense', '900% · ৳9,000.00'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(2));
    });

    testWithDatabase('more income is green and more expense is red', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      Color? colorOf(String key, String text) =>
          tester.widget<Text>(inside(key, text)).style?.color;

      expect(
        colorOf('compare-income', '67% · ৳20,000.00'),
        FinanceColors.light.income,
      );
      expect(
        colorOf('compare-expense', '900% · ৳9,000.00'),
        FinanceColors.light.expense,
      );
    });

    testWithDatabase(
      'a month with nothing before it says the figures are new',
      (tester, db) async {
        useTallScreen(tester);
        await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);

        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();

        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('Compared with August 2026'), findsOneWidget);
        expect(inside('compare-income', 'New, nothing before'), findsOneWidget);
        expect(
          inside('compare-expense', 'New, nothing before'),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('says when nothing changed or nothing is there', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      // August and July are empty, so August compares nothing with nothing.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('August 2026'), findsOneWidget);
      expect(
        inside('compare-income', 'Nothing in either period'),
        findsOneWidget,
      );
    });

    testWithDatabase('cannot go past the current month', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('spending by category', () {
    testWithDatabase(
      'adds sub-categories to their parent and shows each share',
      (tester, db) async {
        useTallScreen(tester);
        final d = await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);

        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byKey(const ValueKey('pie-total')), findsOneWidget);
        expect(inside('category-pie', '৳10,000.00'), findsWidgets);
        // Rent 8,000 is 80%, Food + Groceries 1,500 is 15%, Transport 500 is 5%.
        final rent = find.byKey(ValueKey('legend-${d.rent}'));
        expect(
          find.descendant(of: rent, matching: find.text('80%')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: rent, matching: find.text('৳8,000.00')),
          findsOneWidget,
        );
        final food = find.byKey(ValueKey('legend-${d.basics.food}'));
        expect(
          find.descendant(of: food, matching: find.text('15%')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: food, matching: find.text('৳1,500.00')),
          findsOneWidget,
        );
        final transport = find.byKey(ValueKey('legend-${d.basics.transport}'));
        expect(
          find.descendant(of: transport, matching: find.text('5%')),
          findsOneWidget,
        );
        // The sub-category has no slice of its own.
        expect(find.byKey(ValueKey('legend-${d.groceries}')), findsNothing);
      },
    );

    testWithDatabase('lists the biggest category first', (tester, db) async {
      useTallScreen(tester);
      final d = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      final rentTop = tester
          .getTopLeft(find.byKey(ValueKey('legend-${d.rent}')))
          .dy;
      final foodTop = tester
          .getTopLeft(find.byKey(ValueKey('legend-${d.basics.food}')))
          .dy;
      final transportTop = tester
          .getTopLeft(find.byKey(ValueKey('legend-${d.basics.transport}')))
          .dy;
      expect(rentTop, lessThan(foodTop));
      expect(foodTop, lessThan(transportTop));
    });

    testWithDatabase('groups small categories into Others', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      for (var i = 1; i <= 9; i++) {
        final category = await insertTestCategory(db, name: 'Cat $i');
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: i * 10000,
          accountId: b.cash,
          categoryId: category,
          date: DateTime(2026, 10, 3),
        );
      }
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('legend-others')), findsOneWidget);
      // The three smallest: Cat 1, 2, 3 = 100 + 200 + 300.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('legend-others')),
          matching: find.text('৳600.00'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('says so when nothing was spent', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(
        inside('category-pie', 'No expenses in this period.'),
        findsOneWidget,
      );
      expect(find.byType(PieChart), findsNothing);
    });
  });

  group('income against expense', () {
    testWithDatabase('draws two bars for each of the last six months', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final groups = chart.data.barGroups;
      expect(groups, hasLength(6));
      expect(groups.every((g) => g.barRods.length == 2), isTrue);
      // September and October hold the data: income in taka, then expense.
      expect(groups[4].barRods[0].toY, 30000);
      expect(groups[4].barRods[1].toY, 1000);
      expect(groups[5].barRods[0].toY, 50000);
      expect(groups[5].barRods[1].toY, 10000);
      // May to August are empty.
      expect(
        groups.take(4).every((g) => g.barRods.every((r) => r.toY == 0)),
        isTrue,
      );
      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
    });

    testWithDatabase('follows the month being looked at', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      final groups = tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups;
      // Now Apr to Sep: September is the last bar.
      expect(groups.last.barRods[0].toY, 30000);
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('Oct'), findsNothing);
    });

    testWithDatabase('says so when the months are empty', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(
        inside('income-expense-chart', 'No income or expense in these months.'),
        findsOneWidget,
      );
      expect(find.byType(BarChart), findsNothing);
    });
  });

  group('top expenses', () {
    testWithDatabase('lists the biggest single expenses with their dates', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      final rent = find.byKey(ValueKey('top-${d.rentExpense}'));
      final transport = find.byKey(ValueKey('top-${d.transportExpense}'));
      expect(
        find.descendant(of: rent, matching: find.text('4 Oct · Cash')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rent, matching: find.text('-৳8,000.00')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(rent).dy,
        lessThan(tester.getTopLeft(transport).dy),
      );
      // Four expenses in October: 8,000, 1,200, 500 and 300. Not the
      // transfer and not the correction.
      final tops = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            RegExp(r'^top-\d+$').hasMatch((w.key! as ValueKey<String>).value),
      );
      expect(tops, findsNWidgets(4));
    });

    testWithDatabase('a top expense opens its editor', (tester, db) async {
      useTallScreen(tester);
      final d = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('top-${d.rentExpense}')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byKey(ValueKey('top-${d.rentExpense}')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Edit transaction'), findsOneWidget);
    });
  });

  group('a custom date range', () {
    testWithDatabase(
      'replaces the month and compares with the days right before it',
      (tester, db) async {
        useTallScreen(tester);
        await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);

        await tester.tap(find.byTooltip('Custom date range'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('5'));
        await tester.pump();
        await tester.tap(find.text('9'));
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // 5 to 9 Oct holds only the 500 Transport expense (7 Oct).
        expect(find.text('5 Oct 2026 – 9 Oct 2026'), findsOneWidget);
        expect(find.byTooltip('Previous month'), findsNothing);
        expect(inside('report-summary', '৳500.00'), findsWidgets);
        expect(inside('category-pie', '৳500.00'), findsWidgets);
        // The five days before, 30 Sep to 4 Oct, held the 50,000 income (1 Oct)
        // and 9,500 of expenses (Food 1,200, Groceries 300, Rent 8,000).
        expect(
          find.text('Compared with 30 Sep 2026 – 4 Oct 2026'),
          findsOneWidget,
        );
        expect(inside('compare-income', '100% · ৳50,000.00'), findsOneWidget);
        expect(inside('compare-expense', '95% · ৳9,000.00'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
        // Less income is bad news (red), less expense is good news (green).
        Color? colorOf(String key, String text) =>
            tester.widget<Text>(inside(key, text)).style?.color;
        expect(
          colorOf('compare-income', '100% · ৳50,000.00'),
          FinanceColors.light.expense,
        );
        expect(
          colorOf('compare-expense', '95% · ৳9,000.00'),
          FinanceColors.light.income,
        );
      },
    );

    testWithDatabase('going back to months works', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await tester.tap(find.byTooltip('Custom date range'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear date range'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(inside('report-summary', '৳50,000.00'), findsOneWidget);
    });
  });

  testWithDatabase('updates by itself when a transaction is added', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openReports(tester);
    expect(
      inside('category-pie', 'No expenses in this period.'),
      findsOneWidget,
    );

    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 25000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 5),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    expect(inside('report-summary', '৳250.00'), findsWidgets);
  });

  testWidgets('shows the error with a Retry when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: <Override>[
          reportProvider.overrideWith(
            (ref, range) async =>
                throw const ValidationException('Database is down'),
          ),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Database is down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
