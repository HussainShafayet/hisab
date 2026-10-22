import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> spend(
  AppDatabase db,
  int account,
  int category,
  int amount,
  DateTime date,
) => db.transactionsDao.insertTransaction(
  TransactionsCompanion.insert(
    type: TransactionType.expense,
    amount: amount,
    accountId: account,
    categoryId: Value(category),
    date: date,
  ),
);

void main() {
  testWithDatabase('Home says nothing when there is nothing to say', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedBasics(db);
    // Open, so that the absence means something.
    await showHomeExtras(db);
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('insights')), findsNothing);
  });

  testWithDatabase('Home says when spending went up since last month', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.food, 150000, DateTime(2026, 10, 5));
    await spend(db, b.cash, b.food, 100000, DateTime(2026, 9, 8));
    await showHomeExtras(db);
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('insights')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('insight-spendingUp')))
          .data,
      'You spent 50% more than the same days last month.',
    );
  });

  testWithDatabase('Home shows at most four, the most important first', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.food, 150000, DateTime(2026, 10, 5));
    await spend(db, b.cash, b.food, 100000, DateTime(2026, 9, 8));
    await showHomeExtras(db);
    await pumpAppWithDatabase(tester, db);

    final shown = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('insight-'),
    );
    expect(shown.evaluate().length, lessThanOrEqualTo(4));
    // The warning is the first line.
    final first = tester
        .getTopLeft(find.byKey(const ValueKey('insight-spendingUp')))
        .dy;
    for (final element in shown.evaluate()) {
      expect(
        tester.getTopLeft(find.byWidget(element.widget)).dy,
        greaterThanOrEqualTo(first),
      );
    }
  });

  testWithDatabase('Home updates when a transaction is added', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await spend(db, b.cash, b.food, 100000, DateTime(2026, 9, 8));
    await showHomeExtras(db);
    await pumpAppWithDatabase(tester, db);
    expect(find.byKey(const ValueKey('insight-spendingUp')), findsNothing);

    await spend(db, b.cash, b.food, 300000, DateTime(2026, 10, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('insight-spendingUp')), findsOneWidget);
  });
}
