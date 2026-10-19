import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/budget/presentation/providers/budget_providers.dart';
import 'package:hishab/features/budget/presentation/screens/budget_screen.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Future<void> openBudget(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Budget'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int> setBudget(
  AppDatabase db,
  String month,
  int amount, {
  int? categoryId,
}) => db.budgetsDao.insertBudget(
  BudgetsCompanion.insert(
    month: month,
    amount: amount,
    categoryId: Value(categoryId),
  ),
);

Future<void> spend(
  AppDatabase db,
  Basics b,
  int category,
  int amount,
  DateTime date,
) => addTransaction(
  db,
  type: TransactionType.expense,
  amount: amount,
  accountId: b.cash,
  categoryId: category,
  date: date,
);

Color? colorOf(WidgetTester tester, Finder within, String text) => tester
    .widget<Text>(find.descendant(of: within, matching: find.text(text)))
    .style
    ?.color;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<List<BudgetRow>> budgetsOf(AppDatabase db, String month) =>
    db.budgetsDao.getForMonth(month);

void main() {
  group('an empty month', () {
    testWithDatabase('offers to set a budget or copy last month', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(find.text('No budget for October 2026'), findsOneWidget);
      expect(find.text('Set monthly budget'), findsOneWidget);
      expect(find.text("Copy last month's budget"), findsOneWidget);
    });

    testWithDatabase('sets the monthly budget', (tester, db) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tapText(tester, 'Set monthly budget');
      await tester.enterText(find.byType(TextFormField), '30000');
      await tapText(tester, 'Save');

      expect(find.byKey(const ValueKey('overall-budget')), findsOneWidget);
      expect(find.text('৳30,000.00 left'), findsOneWidget);
      expect(find.text('Spent ৳0.00 of ৳30,000.00'), findsOneWidget);
      final row = (await budgetsOf(db, '2026-10')).single;
      expect(row.amount, 3000000);
      expect(row.categoryId, isNull);
    });

    testWithDatabase('asks for an amount above zero', (tester, db) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      await tapText(tester, 'Set monthly budget');

      await tapText(tester, 'Save');
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '0');
      await tapText(tester, 'Save');
      expect(find.text('The budget must be above zero.'), findsOneWidget);
      expect(await budgetsOf(db, '2026-10'), isEmpty);
    });

    testWithDatabase('cancel sets nothing', (tester, db) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      await tapText(tester, 'Set monthly budget');
      await tester.enterText(find.byType(TextFormField), '500');

      await tapText(tester, 'Cancel');

      expect(await budgetsOf(db, '2026-10'), isEmpty);
    });
  });

  group('progress', () {
    testWithDatabase(
      'shows what is spent, what is left and the level of each budget',
      (tester, db) async {
        useTallScreen(tester);
        final b = await seedBasics(db);
        final rent = await insertTestCategory(db, name: 'Rent');
        await setBudget(db, '2026-10', 3000000); // overall ৳30,000
        await setBudget(db, '2026-10', 800000, categoryId: b.food); // ৳8,000
        await setBudget(
          db,
          '2026-10',
          200000,
          categoryId: b.transport,
        ); // ৳2,000
        await setBudget(db, '2026-10', 1000000, categoryId: rent); // ৳10,000
        await spend(db, b, b.food, 650000, DateTime(2026, 10, 3)); // 81%
        await spend(db, b, b.transport, 300000, DateTime(2026, 10, 4)); // 150%
        await pumpAppWithDatabase(tester, db);
        await openBudget(tester);

        // Overall: 9,500 of 30,000 spent, 21 days left from the 11th.
        expect(find.text('৳20,500.00 left'), findsOneWidget);
        expect(find.text('Spent ৳9,500.00 of ৳30,000.00'), findsOneWidget);
        expect(find.text('31%'), findsOneWidget);
        expect(find.text('৳976.19 per day · 21 days left'), findsOneWidget);

        final food = find.byKey(ValueKey('budget-${b.food}'));
        expect(
          find.descendant(of: food, matching: find.text('81%')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: food,
            matching: find.text('Spent ৳6,500.00 of ৳8,000.00'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: food,
            matching: find.text(
              '৳1,500.00 left · ৳71.42 per day · 21 days left',
            ),
          ),
          findsOneWidget,
        );

        final transport = find.byKey(ValueKey('budget-${b.transport}'));
        expect(
          find.descendant(of: transport, matching: find.text('150%')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: transport,
            matching: find.text('Over by ৳1,000.00'),
          ),
          findsOneWidget,
        );

        final rentTile = find.byKey(ValueKey('budget-$rent'));
        expect(
          find.descendant(of: rentTile, matching: find.text('0%')),
          findsOneWidget,
        );
      },
    );

    testWithDatabase('colors: fine, warning from 80% and over at 100%', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final rent = await insertTestCategory(db, name: 'Rent');
      await setBudget(db, '2026-10', 800000, categoryId: b.food);
      await setBudget(db, '2026-10', 200000, categoryId: b.transport);
      await setBudget(db, '2026-10', 1000000, categoryId: rent);
      await spend(db, b, b.food, 650000, DateTime(2026, 10, 3));
      await spend(
        db,
        b,
        b.transport,
        200000,
        DateTime(2026, 10, 4),
      ); // exactly 100%
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      const colors = FinanceColors.light;
      final primary = Theme.of(tester.element(find.byType(Scaffold).first))
          .colorScheme
          .primary;
      expect(
        colorOf(tester, find.byKey(ValueKey('budget-$rent')), '0%'),
        primary,
      );
      expect(
        colorOf(tester, find.byKey(ValueKey('budget-${b.food}')), '81%'),
        colors.warning,
      );
      expect(
        colorOf(tester, find.byKey(ValueKey('budget-${b.transport}')), '100%'),
        colors.expense,
      );
      expect(find.text('Nothing left'), findsOneWidget);
    });

    testWithDatabase('orders the categories with the most used up first', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 100000, categoryId: b.food);
      await setBudget(db, '2026-10', 100000, categoryId: b.transport);
      await spend(db, b, b.food, 20000, DateTime(2026, 10, 3));
      await spend(db, b, b.transport, 90000, DateTime(2026, 10, 4));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      final transportTop = tester
          .getTopLeft(find.byKey(ValueKey('budget-${b.transport}')))
          .dy;
      final foodTop = tester
          .getTopLeft(find.byKey(ValueKey('budget-${b.food}')))
          .dy;
      expect(transportTop, lessThan(foodTop));
    });

    testWithDatabase(
      'does not count income, transfers or balance adjustments',
      (tester, db) async {
        useTallScreen(tester);
        final b = await seedBasics(db);
        await setBudget(db, '2026-10', 1000000);
        await spend(db, b, b.food, 10000, DateTime(2026, 10, 3));
        await addTransaction(
          db,
          type: TransactionType.income,
          amount: 99999999,
          accountId: b.cash,
          categoryId: b.salary,
          date: DateTime(2026, 10, 3),
        );
        await addTransaction(
          db,
          type: TransactionType.transfer,
          amount: 55555555,
          accountId: b.cash,
          toAccountId: b.bkash,
          date: DateTime(2026, 10, 4),
        );
        await db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 7777777,
            accountId: b.cash,
            categoryId: Value(b.food),
            date: DateTime(2026, 10, 5),
            isAdjustment: const Value(true),
          ),
        );
        await pumpAppWithDatabase(tester, db);
        await openBudget(tester);

        expect(find.text('Spent ৳100.00 of ৳10,000.00'), findsOneWidget);
      },
    );

    testWithDatabase('moves by itself when an expense is added', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 1000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      expect(find.text('Spent ৳0.00 of ৳10,000.00'), findsOneWidget);

      await spend(db, b, b.food, 250000, DateTime(2026, 10, 9));
      await tester.pumpAndSettle();

      expect(find.text('Spent ৳2,500.00 of ৳10,000.00'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });
  });

  group('months', () {
    testWithDatabase('a past month has no per-day amount', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      expect(find.byKey(const ValueKey('overall-per-day')), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('overall-budget')), findsOneWidget);
      expect(find.byKey(const ValueKey('overall-per-day')), findsNothing);
    });

    testWithDatabase('next month can be planned, using all its days', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-11', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      IconButton next() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next().onPressed, isNotNull);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
      // ৳30,000 over 30 days.
      expect(find.text('৳1,000.00 per day · 30 days left'), findsOneWidget);
      expect(next().onPressed, isNull);
    });

    testWithDatabase('each month has its own budget', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-09', 111100);
      await setBudget(db, '2026-10', 222200);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      expect(find.text('Spent ৳0.00 of ৳2,222.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('Spent ৳0.00 of ৳1,111.00'), findsOneWidget);
    });
  });

  group('changing budgets', () {
    testWithDatabase('edits the monthly budget', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byKey(const ValueKey('overall-budget')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '30000',
      );
      await tester.enterText(find.byType(TextFormField), '35000.50');
      await tapText(tester, 'Save');

      expect(find.text('Spent ৳0.00 of ৳35,000.50'), findsOneWidget);
      expect((await budgetsOf(db, '2026-10')).single.amount, 3500050);
    });

    testWithDatabase('removes the monthly budget', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 3000000);
      await setBudget(db, '2026-10', 800000, categoryId: b.food);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byKey(const ValueKey('overall-budget')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Remove');

      expect(find.byKey(const ValueKey('overall-budget')), findsNothing);
      // The category budget stays, and a card offers to set the overall one again.
      expect(find.byKey(const ValueKey('set-overall-budget')), findsOneWidget);
      expect(find.byKey(ValueKey('budget-${b.food}')), findsOneWidget);
    });

    testWithDatabase('adds a category budget', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      expect(find.text('No category budgets yet.'), findsOneWidget);

      await tapText(tester, 'Add category budget');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      // Only expense categories are offered, never income ones.
      expect(find.text('Salary'), findsNothing);
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '8000');
      await tapText(tester, 'Save');

      expect(find.byKey(ValueKey('budget-${b.food}')), findsOneWidget);
      final row = (await budgetsOf(db, '2026-10')).last;
      expect(row.categoryId, b.food);
      expect(row.amount, 800000);
    });

    testWithDatabase('does not offer a category that already has a budget', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 800000, categoryId: b.food);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tapText(tester, 'Add category budget');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();

      // Look at the dropdown's items only: the Food budget is on the screen
      // behind it.
      expect(
        find.widgetWithText(DropdownMenuItem<int>, 'Transport'),
        findsOneWidget,
      );
      expect(find.widgetWithText(DropdownMenuItem<int>, 'Food'), findsNothing);
    });

    testWithDatabase('says when every category already has a budget', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 100, categoryId: b.food);
      await setBudget(db, '2026-10', 100, categoryId: b.transport);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tapText(tester, 'Add category budget');

      expect(
        find.text('Every expense category already has a budget.'),
        findsOneWidget,
      );
    });

    testWithDatabase('asks which category when adding', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      await tapText(tester, 'Add category budget');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly limit'),
        '500',
      );
      await tapText(tester, 'Save');

      expect(find.text('Choose a category'), findsOneWidget);
    });

    testWithDatabase('edits and removes a category budget', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 800000, categoryId: b.food);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byKey(ValueKey('budget-${b.food}')));
      await tester.pumpAndSettle();
      expect(find.text('Food budget'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '9000');
      await tapText(tester, 'Save');
      expect(find.text('Spent ৳0.00 of ৳9,000.00'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('budget-${b.food}')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Remove');

      expect(find.byKey(ValueKey('budget-${b.food}')), findsNothing);
      expect(await budgetsOf(db, '2026-10'), isEmpty);
    });
  });

  group("copying last month's budget", () {
    testWithDatabase('copies everything from the empty state', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-09', 800000, categoryId: b.food);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tapText(tester, "Copy last month's budget");

      expect(
        find.text('Copied 2 budgets from September 2026.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('overall-budget')), findsOneWidget);
      expect(find.byKey(ValueKey('budget-${b.food}')), findsOneWidget);
      expect((await budgetsOf(db, '2026-10')), hasLength(2));
    });

    testWithDatabase('works from the menu when the month has some budgets', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-09', 800000, categoryId: b.food);
      await setBudget(db, '2026-10', 111100);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy last month's budget"));
      await tester.pumpAndSettle();

      expect(find.text('Copied 1 budget from September 2026.'), findsOneWidget);
      // The budget the month already had is kept.
      expect(find.text('Spent ৳0.00 of ৳1,111.00'), findsOneWidget);
    });

    testWithDatabase('says when last month has nothing to copy', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tapText(tester, "Copy last month's budget");

      expect(
        find.text('There is no budget in September 2026 to copy.'),
        findsOneWidget,
      );
    });

    testWithDatabase('says when there is nothing new to copy', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy last month's budget"));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing new to copy'), findsOneWidget);
    });
  });

  testWidgets('shows the error with a Retry when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // No automatic retry, so the failing provider leaves no timers behind.
        retry: (_, _) => null,
        overrides: <Override>[
          monthBudgetProvider.overrideWith(
            (ref, month) =>
                Stream.error(const ValidationException('Database is down')),
          ),
        ],
        child: const MaterialApp(home: BudgetScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Database is down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  group('carrying over what is left', () {
    testWithDatabase('the switch turns it on and off and saves the choice', (
      tester,
      db,
    ) async {
      await seedBasics(db);
      await setBudget(db, '2026-10', 3000000);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('rollover-switch')),
            )
            .value,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('rollover-switch')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('rollover-switch')),
            )
            .value,
        isTrue,
      );
      expect((await db.settingsDao.getAll())['budget_rollover'], 'true');

      await tester.tap(find.byKey(const ValueKey('rollover-switch')));
      await tester.pumpAndSettle();
      expect((await db.settingsDao.getAll())['budget_rollover'], 'false');
    });

    testWithDatabase('adds last month\'s leftover and says so', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.settingsDao.put('budget_rollover', 'true');
      await setBudget(db, '2026-09', 3000000); // ৳30,000
      await setBudget(db, '2026-10', 3000000);
      await setBudget(db, '2026-09', 500000, categoryId: b.food); // ৳5,000
      await setBudget(db, '2026-10', 500000, categoryId: b.food);
      await spend(db, b, b.food, 1000000, DateTime(2026, 9, 12)); // ৳10,000
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      // Overall: 30,000 - 10,000 left over. Food: 5,000 - 10,000 is below
      // zero, so nothing.
      expect(
        find.text('Includes ৳20,000.00 left over from last month'),
        findsOneWidget,
      );
      expect(find.text('Spent ৳0.00 of ৳50,000.00'), findsOneWidget);
      expect(find.byKey(ValueKey('carried-${b.food}')), findsNothing);
    });

    testWithDatabase('editing starts from the amount that was set', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await db.settingsDao.put('budget_rollover', 'true');
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-10', 3000000);
      await spend(db, b, b.food, 1000000, DateTime(2026, 9, 12));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      await tester.tap(find.byKey(const ValueKey('overall-budget')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '30000'), findsOneWidget);
      await tapText(tester, 'Cancel');
    });

    testWithDatabase('adds nothing while the switch is off', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await setBudget(db, '2026-09', 3000000);
      await setBudget(db, '2026-10', 3000000);
      await spend(db, b, b.food, 1000000, DateTime(2026, 9, 12));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(find.byKey(const ValueKey('overall-carried')), findsNothing);
      expect(find.text('Spent ৳0.00 of ৳30,000.00'), findsOneWidget);
    });
  });
}
