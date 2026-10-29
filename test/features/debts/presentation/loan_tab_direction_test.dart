import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// The add button of the Loans screen starts a loan the way of the tab that is
// open: "I'll give" (a liability, money borrowed) starts as a loan taken.

Future<void> openLoans(WidgetTester tester) => openFromMore(tester, 'Loans');

Future<void> saveALoan(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Karim');
  await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
  await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
  await tester.pumpAndSettle();
}

void main() {
  group('the add button of the Loans screen', () {
    testWithDatabase('starts a loan given on the I\'ll get tab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await saveALoan(tester);

      expect(
        (await db.debtsDao.getAllDebts()).single.direction,
        DebtDirection.lent,
      );
    });

    testWithDatabase('starts a loan taken on the I\'ll give tab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.byKey(const ValueKey('tab-give')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await saveALoan(tester);

      expect(
        (await db.debtsDao.getAllDebts()).single.direction,
        DebtDirection.borrowed,
      );
    });

    testWithDatabase('starts a loan given on the People tab', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.byKey(const ValueKey('tab-people')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await saveALoan(tester);

      expect(
        (await db.debtsDao.getAllDebts()).single.direction,
        DebtDirection.lent,
      );
    });

    testWithDatabase('can still be switched in the form', (tester, db) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.byKey(const ValueKey('tab-give')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('direction-lent')));
      await tester.pumpAndSettle();
      await saveALoan(tester);

      expect(
        (await db.debtsDao.getAllDebts()).single.direction,
        DebtDirection.lent,
      );
    });
  });
}
