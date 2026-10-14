import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Future<void> spend(
  AppDatabase db,
  int account,
  int category,
  int amount, {
  DateTime? date,
  TransactionType type = TransactionType.expense,
}) => db.transactionsDao.insertTransaction(
  TransactionsCompanion.insert(
    type: type,
    amount: amount,
    accountId: account,
    categoryId: Value(category),
    date: date ?? DateTime(2026, 10, 5),
  ),
);

String amount(WidgetTester tester, int id) =>
    tester.widget<Text>(find.byKey(ValueKey('category-amount-$id'))).data!;

Finder amountOf(int id) => find.byKey(ValueKey('category-amount-$id'));

void main() {
  testWithDatabase('shows this month on each category, groups rolled up', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    final bazar = await insertTestCategory(
      db,
      name: 'Kacha bazar',
      parentId: b.food,
    );
    final fish = await insertTestCategory(db, name: 'Fish', parentId: bazar);
    await spend(db, b.cash, fish, 20000);
    await spend(db, b.cash, bazar, 5000);
    await spend(db, b.cash, b.food, 1000);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    expect(find.byKey(const ValueKey('amounts-note')), findsOneWidget);
    expect(
      find.text(
        'Amounts are for October 2026. A group counts everything inside it.',
      ),
      findsOneWidget,
    );
    expect(amount(tester, fish), '৳200.00');
    expect(amount(tester, bazar), '৳250.00');
    expect(amount(tester, b.food), '৳260.00');
  });

  testWithDatabase('shows nothing for a category with no money this month', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.food, 1000);
    // Last month and next month are not this month.
    await spend(db, b.cash, b.transport, 500, date: DateTime(2026, 9, 30));
    await spend(db, b.cash, b.transport, 700, date: DateTime(2026, 11));
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    expect(amountOf(b.food), findsOneWidget);
    expect(amountOf(b.transport), findsNothing);
  });

  testWithDatabase('has income on the Income tab', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.salary, 90000, type: TransactionType.income);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(amount(tester, b.salary), '৳900.00');
  });

  testWithDatabase('does not count balance corrections', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: 9999,
        accountId: b.cash,
        categoryId: Value(b.food),
        date: DateTime(2026, 10, 5),
        isAdjustment: const Value(true),
      ),
    );
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    expect(amountOf(b.food), findsNothing);
  });

  testWithDatabase('a closed group keeps its total, the rows inside hide', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    final bazar = await insertTestCategory(
      db,
      name: 'Kacha bazar',
      parentId: b.food,
    );
    await spend(db, b.cash, bazar, 5000);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    await tester.tap(find.byKey(ValueKey('category-toggle-${b.food}')));
    await tester.pumpAndSettle();

    expect(amount(tester, b.food), '৳50.00');
    expect(amountOf(bazar), findsNothing);
  });

  testWithDatabase('follows a new transaction', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');
    expect(amountOf(b.food), findsNothing);

    await spend(db, b.cash, b.food, 4200);
    await tester.pumpAndSettle();

    expect(amount(tester, b.food), '৳42.00');
  });

  testWithDatabase('does not break on a small phone with a long amount', (
    tester,
    db,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.food, 123456789012);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Categories');

    expect(tester.takeException(), isNull);
    expect(amountOf(b.food), findsOneWidget);
  });
}
