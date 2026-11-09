import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
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
}
