import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// A friend paid a bill for me: one entry on the new loan form makes the expense
// and the money I owe, and no account balance changes.

Future<void> openNewLoan(WidgetTester tester) async {
  await openFromMore(tester, 'Loans');
  await tester.tap(find.byKey(const ValueKey('tab-give')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> fillIn(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Karim');
  await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
  await tester.pumpAndSettle();
}

void main() {
  testWithDatabase('saves the expense and the loan together', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openNewLoan(tester);
    await fillIn(tester);

    await tapKey(tester, 'paid-for-me');
    await tapKey(tester, 'paid-for-me-category');
    await tester.tap(find.byKey(ValueKey('category-option-${b.food}')));
    await tester.pumpAndSettle();
    await save(tester);

    final debt = (await db.debtsDao.getAllDebts()).single;
    expect(debt.direction, DebtDirection.borrowed);
    expect(debt.amount, 25000);
    final expense = (await db.transactionsDao.getAll()).firstWhere(
      (t) => !t.isAdjustment,
    );
    expect(expense.amount, 25000);
    expect(expense.categoryId, b.food);
    expect(expense.accountId, debt.accountId);
  });

  testWithDatabase('asks for a category first', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openNewLoan(tester);
    await fillIn(tester);

    await tapKey(tester, 'paid-for-me');
    await save(tester);

    expect(find.byKey(const ValueKey('form-error')), findsOneWidget);
    expect(await db.debtsDao.getAllDebts(), isEmpty);
  });

  testWithDatabase('is only there for money I took', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openNewLoan(tester);
    expect(find.byKey(const ValueKey('paid-for-me')), findsOneWidget);

    await tapKey(tester, 'direction-lent');

    expect(find.byKey(const ValueKey('paid-for-me')), findsNothing);
  });
}
