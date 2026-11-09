import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// Today is Sunday 11 October 2026.
Future<void> teaEveryDay(AppDatabase db, Basics b, int times) async {
  for (var i = 0; i < times; i++) {
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 3000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 1 + i),
    );
  }
}

Future<void> openInsights(WidgetTester tester) =>
    openFromMore(tester, 'Insights & habits');

void main() {
  group('the Insights & habits screen', () {
    testWithDatabase('opens from More with a tip', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openInsights(tester);

      expect(find.byKey(const ValueKey('tip-card')), findsOneWidget);
      final first = tester
          .widget<Text>(find.byKey(const ValueKey('tip-text')))
          .data;

      await tester.tap(find.byKey(const ValueKey('tip-next')));
      await tester.pumpAndSettle();
      final second = tester
          .widget<Text>(find.byKey(const ValueKey('tip-text')))
          .data;
      expect(second, isNot(first));
    });

    testWithDatabase('says there is nothing yet with no entries', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openInsights(tester);

      expect(find.byKey(const ValueKey('no-insights')), findsOneWidget);
      expect(find.byKey(const ValueKey('no-habits')), findsOneWidget);
    });

    testWithDatabase('lists a habit and opens its entries', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await teaEveryDay(db, b, 9);
      await pumpAppWithDatabase(tester, db);
      await openInsights(tester);

      final habit = find.byKey(ValueKey('habit-${b.food}'));
      await tester.ensureVisible(habit);
      expect(
        find.descendant(of: habit, matching: find.text('9 times in 30 days')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: habit, matching: find.text('৳270.00')),
        findsOneWidget,
      );

      await tester.tap(habit);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Food')),
        findsOneWidget,
      );
    });

    testWithDatabase('a home card says See all and opens the screen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      // Spending that jumped against last month gives the card something.
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 100000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 9, 3),
      );
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 400000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      await showHomeExtras(db);
      await pumpAppWithDatabase(tester, db);

      final seeAll = find.byKey(const ValueKey('insights-see-all'));
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      expect(find.text('Insights & habits'), findsWidgets);
      expect(find.byKey(const ValueKey('insights-all')), findsOneWidget);
    });
  });
}
