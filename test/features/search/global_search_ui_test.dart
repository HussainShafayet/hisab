import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

// Today is Sunday 11 October 2026.
void main() {
  group('the search box on Home', () {
    testWithDatabase('asks for something to look for first', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-hint')), findsOneWidget);
    });

    testWithDatabase('finds a transaction by its note and opens it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final id = await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
        note: 'Dinner with Rahim',
      );
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('global-search')),
        'rahim',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('search-tx-$id')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('search-tx-$id')));
      await tester.pumpAndSettle();
      expect(find.text('Edit transaction'), findsOneWidget);
    });

    testWithDatabase('finds an account and a category too', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('global-search')),
        'bkash',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('search-account-${b.bkash}')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('global-search')),
        'food',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('search-category-${b.food}')), findsOneWidget);
    });

    testWithDatabase('says when nothing matches', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('global-search')),
        'zzzzz',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
    });
  });
}
