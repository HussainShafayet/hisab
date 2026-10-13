import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  // "Now" in widget tests is Sunday 11 October 2026: 21 days left.
  testWithDatabase('Home tells how much can be spent today', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await BudgetsRepository(db)
        .setBudget(month: DateTime(2026, 10), amount: 3150000);
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 1050000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 3),
    );
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 40000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 11, 9),
    );
    await pumpAppWithDatabase(tester, db);

    expect(textOf(tester, 'safe-label'), 'You can spend today');
    expect(textOf(tester, 'safe-amount'), '৳600.00');
    expect(
      textOf(tester, 'safe-detail'),
      '৳1,000.00 a day · ৳400.00 spent today',
    );
    expect(
      textOf(tester, 'safe-note'),
      '৳21,000.00 of the budget is left for 21 days.',
    );
  });

  testWithDatabase('Home warns when today is overspent', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await BudgetsRepository(db)
        .setBudget(month: DateTime(2026, 10), amount: 3150000);
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 180000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 11, 9),
    );
    await pumpAppWithDatabase(tester, db);

    expect(textOf(tester, 'safe-label'), "Over today's share");
    expect(textOf(tester, 'safe-amount'), '৳300.00');
  });

  testWithDatabase('Home says when the budget is used up', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await BudgetsRepository(db)
        .setBudget(month: DateTime(2026, 10), amount: 1000000);
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 1200000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 3),
    );
    await pumpAppWithDatabase(tester, db);

    expect(
      textOf(tester, 'safe-label'),
      'Over the budget, counting the bills to come',
    );
    expect(textOf(tester, 'safe-amount'), '৳2,000.00');
  });

  testWithDatabase('Home asks for a budget when there is none', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('safe-no-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('safe-amount')), findsNothing);
  });
}
