import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import 'budget_screen_test.dart' show openBudget, setBudget, spend;

// Today is Sunday 11 October 2026: 11 days of 31 are gone.
void main() {
  group('the budget tab tells more', () {
    testWithDatabase('says where the month is heading', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 100000);
      // ৳550 in 11 days: ৳1,550 for the month, ৳550 over.
      await spend(db, b, b.food, 55000, DateTime(2026, 10, 5));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      final text = tester
          .widget<Text>(find.byKey(const ValueKey('overall-projection')))
          .data!;
      expect(text, contains('At this pace you will spend ৳1,550.00'));
      expect(text, contains('৳550.00 over the budget'));
    });

    testWithDatabase('a slow month stays within the budget', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 500000);
      await spend(db, b, b.food, 10000, DateTime(2026, 10, 5));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('overall-projection')))
            .data,
        contains('within the budget'),
      );
    });

    testWithDatabase('shows how much is planned in categories', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 1000000);
      await setBudget(db, '2026-10', 300000, categoryId: b.food);
      await setBudget(db, '2026-10', 200000, categoryId: b.transport);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(find.byKey(const ValueKey('budget-plan')), findsOneWidget);
      expect(find.text('৳5,000.00 of ৳10,000.00 is planned'), findsOneWidget);
      expect(find.text('৳5,000.00 is not planned yet.'), findsOneWidget);
    });

    testWithDatabase('warns when the categories ask for too much', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 400000);
      await setBudget(db, '2026-10', 300000, categoryId: b.food);
      await setBudget(db, '2026-10', 200000, categoryId: b.transport);
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(
        find.text('The categories ask for ৳1,000.00 more than the month.'),
        findsOneWidget,
      );
    });

    testWithDatabase('lists spending with no budget and offers one', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 1000000);
      await setBudget(db, '2026-10', 300000, categoryId: b.food);
      await spend(db, b, b.food, 10000, DateTime(2026, 10, 5));
      await spend(db, b, b.transport, 8000, DateTime(2026, 10, 6));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('unbudgeted-total')))
            .data,
        '৳80.00',
      );
      expect(find.text('Transport · ৳80.00'), findsOneWidget);
      // Food has a budget, so it is not here.
      expect(find.text('Food · ৳100.00'), findsNothing);

      await tester.ensureVisible(
        find.byKey(ValueKey('set-budget-${b.transport}')),
      );
      await tester.tap(find.byKey(ValueKey('set-budget-${b.transport}')));
      await tester.pumpAndSettle();
      expect(find.text('Add category budget'), findsOneWidget);
      // The dialog starts on that category.
      expect(find.text('Transport'), findsWidgets);
    });

    testWithDatabase('no card when everything is covered', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await setBudget(db, '2026-10', 1000000);
      await setBudget(db, '2026-10', 300000, categoryId: b.food);
      await spend(db, b, b.food, 10000, DateTime(2026, 10, 5));
      await pumpAppWithDatabase(tester, db);
      await openBudget(tester);

      expect(find.byKey(const ValueKey('budget-unbudgeted')), findsNothing);
    });
  });
}
