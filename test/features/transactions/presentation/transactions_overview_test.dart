import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';
import 'transactions_screen_test.dart' show openTab, row, seedMonth;

void main() {
  group('the transaction list overview', () {
    testWithDatabase('type chips show how many there are and narrow the list', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final m = await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('All · 4'), findsOneWidget);
      expect(find.text('Expense · 2'), findsOneWidget);
      expect(find.text('Income · 1'), findsOneWidget);
      expect(find.text('Transfer · 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('type-income')));
      await tester.pumpAndSettle();
      expect(row(m.salary), findsOneWidget);
      expect(row(m.lunch), findsNothing);
      // The other counts stay, so a tap on one shows what it would give.
      expect(find.text('Expense · 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('type-all')));
      await tester.pumpAndSettle();
      expect(row(m.lunch), findsOneWidget);
    });

    testWithDatabase('a line of facts under the summary', (tester, db) async {
      useTallScreen(tester);
      await seedMonth(db);
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(find.text('4 entries'), findsOneWidget);
      expect(find.text('Biggest ৳250.00'), findsOneWidget);
      expect(find.text('Most on Food'), findsOneWidget);
      expect(find.byKey(const ValueKey('stat-per-day')), findsOneWidget);
    });

    testWithDatabase('a category inside another says where it sits', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final fish = await insertTestCategory(db, name: 'Fish', parentId: b.food);
      final id = await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 40000,
        accountId: b.cash,
        categoryId: fish,
        date: DateTime(2026, 10, 11, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await openTab(tester);

      expect(
        find.descendant(of: row(id), matching: find.textContaining('Food')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(id), matching: find.text('Fish')),
        findsOneWidget,
      );
    });
  });

  group('the balance of each kind of account on the form', () {
    testWithDatabase('shows what cash, bKash and the bank hold', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await insertTestAccount(
        db,
        name: 'bKash',
        type: AccountType.mobileBanking,
      );
      await insertTestAccount(db, name: 'City', type: AccountType.bank);
      final pay = await insertTestCategory(
        db,
        name: 'Pay',
        type: CategoryType.income,
      );
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 500000,
        accountId: cash,
        categoryId: pay,
        date: DateTime(2026, 10, 1),
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.byKey(const ValueKey('type-balance-cash')), findsOneWidget);
      expect(find.textContaining('Cash ৳5,000.00'), findsOneWidget);
      expect(find.textContaining('Mobile banking ৳0.00'), findsOneWidget);
      expect(find.textContaining('Bank ৳0.00'), findsOneWidget);
    });
  });
}
