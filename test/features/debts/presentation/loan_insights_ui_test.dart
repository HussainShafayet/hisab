import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/pump_app.dart';
import 'debts_screen_test.dart' show make;

Future<void> openLoans(WidgetTester tester) => openFromMore(tester, 'Loans');

// "Now" in widget tests is Sunday 11 October 2026.
void main() {
  group('the loans summary', () {
    testWithDatabase('says how the loans stand', (tester, db) async {
      useTallScreen(tester);
      await make(db, amount: 500000);
      await make(
        db,
        person: 'Karim',
        direction: DebtDirection.borrowed,
        amount: 200000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('loan-net'))).data,
        'You will get ৳3,000.00 more than you give.',
      );
    });

    testWithDatabase('lists what falls due soon and opens it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final soon = await make(db, dueOn: DateTime(2026, 10, 14));
      await make(db, person: 'Karim', dueOn: DateTime(2026, 12, 30));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(const ValueKey('loan-upcoming')), findsOneWidget);
      expect(find.byKey(ValueKey('upcoming-$soon')), findsOneWidget);
      expect(find.text('in 3 days'), findsOneWidget);
      // Far away: not in the list.
      expect(find.textContaining('Karim ·'), findsNothing);

      await tester.tap(find.byKey(ValueKey('upcoming-$soon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remaining')), findsOneWidget);
    });

    testWithDatabase('has no Coming up when nothing is due', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(const ValueKey('loan-upcoming')), findsNothing);
    });
  });

  group('search and sort', () {
    testWithDatabase('a search keeps the names that match', (tester, db) async {
      useTallScreen(tester);
      await make(db);
      await make(db, person: 'Karim');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await tester.tap(find.byKey(const ValueKey('loan-search-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('loan-search')), 'kar');
      await tester.pumpAndSettle();

      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('Rahim'), findsNothing);

      // Closing the search shows everyone again.
      await tester.tap(find.byKey(const ValueKey('loan-search-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Rahim'), findsOneWidget);
    });

    testWithDatabase('can put the biggest amount left first', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, person: 'Small', amount: 10000);
      await make(db, person: 'Large', amount: 900000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await tester.tap(find.byKey(const ValueKey('loan-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biggest left first'));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Large')).dy,
        lessThan(tester.getTopLeft(find.text('Small')).dy),
      );
    });
  });

  group('pay it off in parts', () {
    testWithDatabase('a loan page shows a monthly plan', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 120000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.text('Rahim'));
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('payoff-line'));
      await tester.ensureVisible(line);
      expect(tester.widget<Text>(line).data, '৳200.00 a month for 6 months.');

      await tester.tap(find.byKey(const ValueKey('payoff-3')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(line).data, '৳400.00 a month for 3 months.');
      expect(id, isPositive);
    });

    testWithDatabase('a loan that is paid has no plan', (tester, db) async {
      useTallScreen(tester);
      await make(db, amount: 100000, paid: 100000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.byKey(const ValueKey('show-settled')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rahim'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('payoff-card')), findsNothing);
    });
  });
}
