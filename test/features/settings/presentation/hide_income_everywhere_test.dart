import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
final hiddenIncome = find.byKey(const ValueKey('hidden-income'));

/// ৳1,000 earned and ৳250 spent in October, income hidden when [hide].
Future<Basics> earnedAndSpent(AppDatabase db, {bool hide = true}) async {
  final b = await seedBasics(db);
  await addTransaction(
    db,
    type: TransactionType.income,
    amount: 100000,
    accountId: b.cash,
    categoryId: b.salary,
    date: DateTime(2026, 10, 2, 9),
  );
  await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 25000,
    accountId: b.cash,
    categoryId: b.food,
    date: DateTime(2026, 10, 3, 9),
  );
  if (hide) {
    await SettingsRepository(db).update((p) => p.copyWith(hideIncome: true));
  }
  return b;
}

Future<void> openReports(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Reports'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('hiding income on Reports', () {
    testWithDatabase('leaves out what would give the income away', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('savings-rate')), findsNothing);
      expect(find.byKey(const ValueKey('pie-income')), findsNothing);
      expect(hiddenIncome, findsWidgets);
      expect(find.text('৳1,000.00'), findsNothing);
      expect(find.text('+৳1,000.00'), findsNothing);
    });

    testWithDatabase('shows all of it again when income is not hidden', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await earnedAndSpent(db, hide: false);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('savings-rate')), findsOneWidget);
      expect(find.byKey(const ValueKey('pie-income')), findsOneWidget);
    });

    testWithDatabase('shows only spending in the income vs expense chart', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('income-expense-chart')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Spending by month'), findsOneWidget);
      expect(find.text('Income vs expense'), findsNothing);
    });
  });

  group('hiding income elsewhere', () {
    testWithDatabase('hides what an income category took in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await earnedAndSpent(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Categories');
      await tester.tap(find.text('Income').first);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('category-amount-${b.salary}')), findsNothing);
      expect(hiddenIncome, findsWidgets);
    });

    testWithDatabase('hides the amount of a repeating income', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await earnedAndSpent(db);
      await RecurringRepository(db).createRule(
        title: 'Salary',
        type: TransactionType.income,
        amount: 500000,
        accountId: b.cash,
        categoryId: b.salary,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 11, 1),
        autoAdd: false,
        remind: false,
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Recurring');

      expect(find.text('Salary'), findsOneWidget);
      expect(hiddenIncome, findsOneWidget);
      expect(find.text('৳5,000.00'), findsNothing);
    });
  });

  group('hiding balances on Accounts', () {
    testWithDatabase('shows dots for the total', (tester, db) async {
      useTallScreen(tester);
      await earnedAndSpent(db, hide: false);
      await SettingsRepository(db)
          .update((p) => p.copyWith(hideBalances: true));
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(const ValueKey('balance-hidden')), findsOneWidget);
      expect(find.byKey(const ValueKey('total-balance')), findsNothing);
    });
  });
}
