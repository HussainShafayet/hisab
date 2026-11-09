import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

String shown(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  group('the add form tells how the category stands', () {
    testWithDatabase(
      'says what the category holds this month, and after this',
      (tester, db) async {
        useTallScreen(tester);
        final b = await seedBasics(db);
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 420000,
          accountId: b.cash,
          categoryId: b.food,
          date: DateTime(2026, 10, 3, 12),
        );
        // Last month does not count.
        await addTransaction(
          db,
          type: TransactionType.expense,
          amount: 99900,
          accountId: b.cash,
          categoryId: b.food,
          date: DateTime(2026, 9, 28, 12),
        );
        await pumpAppWithDatabase(tester, db);
        await openAddForm(tester);
        await chooseCategory(tester, b.food);

        expect(
          shown(tester, 'standing-money'),
          'Spent on Food this month: ৳4,200.00',
        );

        await typeAmount(tester, '500');
        await tester.pumpAndSettle();

        expect(
          shown(tester, 'standing-money'),
          'Spent on Food this month: ৳4,200.00, ৳4,700.00 after this',
        );
        expect(find.byKey(const ValueKey('standing-budget')), findsNothing);
      },
    );

    testWithDatabase('adds what is left of the budget that covers it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          categoryId: Value(b.food),
          amount: 1000000,
        ),
      );
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 420000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await chooseCategory(tester, b.food);

      expect(
        shown(tester, 'standing-budget'),
        'Budget for Food: ৳5,800.00 left',
      );

      await typeAmount(tester, '7000');
      await tester.pumpAndSettle();

      expect(
        shown(tester, 'standing-budget'),
        'Budget for Food: over by ৳1,200.00 after this',
      );
    });

    testWithDatabase('says received for an income category', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 5000000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 1, 9),
      );
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await chooseCategory(tester, b.salary);

      expect(
        shown(tester, 'standing-money'),
        'Received in Salary this month: ৳50,000.00',
      );
    });

    testWithDatabase('does not repeat the wallets under the account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.byKey(const ValueKey('type-balances')), findsNothing);
      expect(find.byKey(const ValueKey('account-field')), findsOneWidget);
    });
  });
}
