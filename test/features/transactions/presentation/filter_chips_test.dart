import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
Future<void> openTransactions(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Transactions'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the chips of the filter', () {
    testWithDatabase('show each option that is set and take it off', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      Future<int> spend(int amount, String note, {Feeling? feeling}) =>
          db.transactionsDao.insertTransaction(
            TransactionsCompanion.insert(
              type: TransactionType.expense,
              amount: amount,
              accountId: b.cash,
              categoryId: Value(b.food),
              date: DateTime(2026, 10, 9, 12),
              note: Value(note),
              feeling: Value(feeling),
            ),
          );
      final gadget = await spend(80000, 'Gadget', feeling: Feeling.regret);
      final snack = await spend(20000, 'Snack', feeling: Feeling.regret);
      final rent = await spend(90000, 'Rent', feeling: Feeling.need);
      Finder row(int id) => find.byKey(ValueKey('transaction-$id'));
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);
      expect(find.byKey(const ValueKey('filter-chips')), findsNothing);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('filter-min-amount')),
        '500',
      );
      await tapKey(tester, 'filter-feeling-regret');
      await tapKey(tester, 'filter-apply');

      // Two chips, and only the regret over ৳500 is listed.
      expect(find.byKey(const ValueKey('filter-chip-amount')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter-chip-feeling')), findsOneWidget);
      expect(find.text('From ৳500.00'), findsOneWidget);
      expect(find.text('Regret'), findsWidgets);
      expect(row(gadget), findsOneWidget);
      expect(row(snack), findsNothing);
      expect(row(rent), findsNothing);

      // Taking off the amount brings the small regret back, not the need.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('filter-chip-amount')),
          matching: find.byTooltip('Take this off'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('filter-chip-amount')), findsNothing);
      expect(find.byKey(const ValueKey('filter-chip-feeling')), findsOneWidget);
      expect(row(snack), findsOneWidget);
      expect(row(rent), findsNothing);

      await tester.tap(find.byTooltip('Take this off'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('filter-chips')), findsNothing);
      expect(row(rent), findsOneWidget);
    });

    testWithDatabase('name the category, account and an amount range', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openTransactions(tester);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('filter-min-amount')),
        '100',
      );
      await tester.enterText(
        find.byKey(const ValueKey('filter-max-amount')),
        '900',
      );
      await tapKey(tester, 'filter-apply');

      expect(find.text('৳100.00 – ৳900.00'), findsOneWidget);
    });
  });
}
