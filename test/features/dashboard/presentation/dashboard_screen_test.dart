import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:hishab/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Finder inside(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// Today is Sunday 11 Oct 2026, so the week runs Sunday 11 to Saturday 17.
class SeededMonth {
  const SeededMonth(this.basics, this.newest, this.oldest);

  final Basics basics;
  final int newest;
  final int oldest;
}

Future<SeededMonth> seedMonth(AppDatabase db) async {
  final b = await seedBasics(db);
  Future<int> expense(int category, int amount, DateTime date) =>
      addTransaction(
        db,
        type: TransactionType.expense,
        amount: amount,
        accountId: b.cash,
        categoryId: category,
        date: date,
      );

  final oldest = await addTransaction(
    db,
    type: TransactionType.income,
    amount: 5000000,
    accountId: b.cash,
    categoryId: b.salary,
    date: DateTime(2026, 10, 1, 10),
  );
  await expense(b.food, 120000, DateTime(2026, 10, 3)); // 1,200
  await addTransaction(
    db,
    type: TransactionType.transfer,
    amount: 100000,
    accountId: b.cash,
    toAccountId: b.bkash,
    date: DateTime(2026, 10, 9, 10),
  );
  await expense(
    b.transport,
    7000,
    DateTime(2026, 10, 10, 18),
  ); // Saturday, last week
  await expense(b.transport, 30000, DateTime(2026, 10, 11, 9)); // today
  await expense(b.food, 45000, DateTime(2026, 10, 11, 12)); // today
  final newest = await expense(
    b.food,
    10000,
    DateTime(2026, 10, 14, 12),
  ); // this week
  return SeededMonth(b, newest, oldest);
}

Future<int> budget(AppDatabase db, int amount) => db.budgetsDao.insertBudget(
  BudgetsCompanion.insert(month: '2026-10', amount: amount),
);

void main() {
  testWithDatabase(
    'shows the month, the balance, the budget, spending and recent transactions',
    (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await budget(db, 2000000); // ৳20,000
      await pumpAppWithDatabase(tester, db);

      expect(appBarTitle('Home'), findsOneWidget);
      // Cash 50,000 - 2,120 - 1,000 transferred out, bKash 1,000.
      expect(inside('total-balance', '৳47,880.00'), findsOneWidget);

      expect(find.text('This month · October 2026'), findsOneWidget);
      expect(find.text('৳50,000.00'), findsOneWidget); // income
      expect(find.text('৳2,120.00'), findsOneWidget); // expense, no transfer
      expect(inside('spent-today', '৳750.00'), findsOneWidget);
      expect(
        inside('spent-week', '৳850.00'),
        findsOneWidget,
      ); // Saturday 10th is last week

      // Budget ring: 2,120 of 20,000 is 10%.
      expect(inside('budget-ring', '10%'), findsOneWidget);
      expect(inside('budget-ring', '৳17,880.00 left'), findsOneWidget);
      expect(
        inside('budget-ring', 'Spent ৳2,120.00 of ৳20,000.00'),
        findsOneWidget,
      );
      expect(
        inside('budget-ring', '৳851.42 per day · 21 days left'),
        findsOneWidget,
      );
    },
  );

  testWithDatabase('lists the top categories of the month with their share', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedMonth(db);
    await pumpAppWithDatabase(tester, db);

    // Food 1,200 + 450 + 100 = 1,750 of 2,120; Transport 300 + 70 = 370.
    expect(inside('top-categories', 'Food'), findsOneWidget);
    expect(inside('top-categories', '৳1,750.00'), findsOneWidget);
    expect(inside('top-categories', '83%'), findsOneWidget);
    expect(inside('top-categories', 'Transport'), findsOneWidget);
    expect(inside('top-categories', '৳370.00'), findsOneWidget);
    expect(inside('top-categories', '17%'), findsOneWidget);
  });

  testWithDatabase('shows the five latest transactions, newest first', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final d = await seedMonth(db);
    await pumpAppWithDatabase(tester, db);

    final recent = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          RegExp(r'^recent-\d+$').hasMatch((w.key! as ValueKey<String>).value),
    );
    expect(recent, findsNWidgets(5));
    expect(find.byKey(ValueKey('recent-${d.newest}')), findsOneWidget);
    // The oldest transaction (1 Oct) is not among the latest five.
    expect(find.byKey(ValueKey('recent-${d.oldest}')), findsNothing);
    final first = tester
        .getTopLeft(find.byKey(ValueKey('recent-${d.newest}')))
        .dy;
    final last = tester.getTopLeft(recent.last).dy;
    expect(first, lessThan(last));
  });

  testWithDatabase('has sensible empty states', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);

    expect(inside('total-balance', '৳0.00'), findsOneWidget);
    expect(find.text('No monthly budget'), findsOneWidget);
    expect(find.text('No spending this month yet.'), findsOneWidget);
    expect(find.text('No transactions yet.'), findsOneWidget);
    expect(inside('spent-today', '৳0.00'), findsOneWidget);
  });

  testWithDatabase('the budget ring turns orange at 80% and red at 100%', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await budget(db, 100000); // ৳1,000
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 85000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 3),
    );
    await pumpAppWithDatabase(tester, db);

    Color? ringColor() => tester
        .widget<Text>(find.byKey(const ValueKey('ring-percent')))
        .style
        ?.color;

    expect(find.text('85%'), findsOneWidget);
    expect(ringColor(), FinanceColors.light.warning);

    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 15000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 4),
    );
    await tester.pumpAndSettle();

    expect(inside('budget-ring', '100%'), findsOneWidget);
    expect(find.text('Nothing left'), findsOneWidget);
    expect(ringColor(), FinanceColors.light.expense);
  });

  testWithDatabase('updates by itself when a transaction is added', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    expect(inside('spent-today', '৳0.00'), findsOneWidget);

    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 25000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 11, 10),
    );
    await tester.pumpAndSettle();

    expect(inside('spent-today', '৳250.00'), findsOneWidget);
    expect(inside('total-balance', '-৳250.00'), findsOneWidget);
    expect(find.text('No transactions yet.'), findsNothing);
  });

  testWithDatabase(
    'a balance correction changes the balance but not income or expense',
    (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.income,
          amount: 20000,
          accountId: b.cash,
          categoryId: Value(b.salary),
          date: DateTime(2026, 10, 5),
          isAdjustment: const Value(true),
        ),
      );
      await pumpAppWithDatabase(tester, db);

      expect(inside('total-balance', '৳200.00'), findsOneWidget);
      // Income and expense stay at zero; the balance cell is zero too.
      expect(find.text('৳0.00'), findsNWidgets(5));
    },
  );

  group('going elsewhere', () {
    testWithDatabase('the budget ring opens the Budget tab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('budget-ring')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Budget'), findsOneWidget);
    });

    testWithDatabase('See all opens the Transactions tab', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Transactions'), findsOneWidget);
    });

    testWithDatabase('the balance card opens Accounts', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('total-balance')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Accounts'), findsOneWidget);
    });

    testWithDatabase('a recent transaction opens its editor', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final d = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(ValueKey('recent-${d.newest}')));
      await tester.pumpAndSettle();

      expect(appBarTitle('Edit transaction'), findsOneWidget);
    });

    testWithDatabase('the empty state can start a transaction', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Add transaction'), findsOneWidget);
    });
  });

  testWidgets('shows the error with a Retry when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: <Override>[
          dashboardProvider.overrideWith(
            (ref) async => throw const ValidationException('Database is down'),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Database is down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
