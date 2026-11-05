import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import 'reports_screen_test.dart' show openReports, seedReports;

Finder rowOf(int id) => find.byKey(ValueKey('transaction-$id'));

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

// Today is Sunday 11 October 2026; the month is October.
void main() {
  group('from a report to the entries behind it', () {
    testWithDatabase('the Expense figure lists the month\'s expenses', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await tester.tap(find.byKey(const ValueKey('figure-Expense')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Expense'),
        ),
        findsOneWidget,
      );
      expect(rowOf(s.rentExpense), findsOneWidget);
      expect(rowOf(s.transportExpense), findsOneWidget);

      // Back to the report where it was.
      await back(tester);
      expect(find.byKey(const ValueKey('report-summary')), findsOneWidget);
    });

    testWithDatabase('a category of the pie lists only its entries', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await tester.ensureVisible(find.byKey(ValueKey('legend-${s.rent}')));
      await tester.tap(find.byKey(ValueKey('legend-${s.rent}')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Rent')),
        findsOneWidget,
      );
      expect(rowOf(s.rentExpense), findsOneWidget);
      expect(rowOf(s.transportExpense), findsNothing);
    });

    testWithDatabase('an account row lists what touched it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      final row = find.byKey(ValueKey('account-total-${s.basics.cash}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Cash')),
        findsOneWidget,
      );
      expect(rowOf(s.rentExpense), findsOneWidget);
    });

    testWithDatabase('a branch of the tree has a button for its entries', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final s = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      final open = find.byKey(ValueKey('tree-open-${s.basics.food}'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();

      // Food and what is inside it (Groceries) are both listed.
      expect(find.text('Groceries'), findsWidgets);
      expect(rowOf(s.rentExpense), findsNothing);
    });
  });

  group('the highlights', () {
    testWithDatabase('name the biggest day and open it', (tester, db) async {
      useTallScreen(tester);
      final s = await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      expect(find.byKey(const ValueKey('report-highlights')), findsOneWidget);
      final tile = find.byKey(const ValueKey('highlight-day'));
      await tester.ensureVisible(tile);
      // Rent on the 4th is the biggest day.
      expect(
        find.descendant(of: tile, matching: find.textContaining('৳8,000.00')),
        findsOneWidget,
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(rowOf(s.rentExpense), findsOneWidget);
      expect(rowOf(s.transportExpense), findsNothing);
    });

    testWithDatabase('draw a bar for every weekday', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('weekday-bar-0')));
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey('weekday-bar-$i')), findsOneWidget);
      }
    });
  });
}
