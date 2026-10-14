import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> write(AppDatabase db, Basics b, int day, {int amount = 1000}) =>
    addTransaction(
      db,
      type: TransactionType.expense,
      amount: amount,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, day, 12),
    );

void main() {
  testWithDatabase('Home asks for an entry when there is no streak', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('streak-card')), findsOneWidget);
    expect(
      find.text('Write an entry today to start a streak!'),
      findsOneWidget,
    );
    expect(find.text('0 of 11 badges'), findsOneWidget);
  });

  testWithDatabase('Home shows the streak and the spend-free days', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    // Today is Sunday 11 October: 9, 10 and 11 in a row, and the 8th with none.
    for (final d in [7, 9, 10, 11]) {
      await write(db, b, d);
    }
    await pumpAppWithDatabase(tester, db);

    expect(find.text('3 days in a row'), findsOneWidget);
    // 8 October had no spending (and 1-6 are before the first entry).
    expect(find.text('1 spend-free day this month'), findsOneWidget);
  });

  testWithDatabase('the streak card opens the badges', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await write(db, b, 11);
    await pumpAppWithDatabase(tester, db);

    await tester.tap(find.byKey(const ValueKey('streak-card')));
    await tester.pumpAndSettle();

    expect(find.text('Badges'), findsWidgets);
    expect(find.text('First step'), findsOneWidget);
    expect(find.byKey(const ValueKey('badges-count')), findsOneWidget);
    expect(find.text('1 of 11 badges'), findsOneWidget);
  });

  testWithDatabase('there is no streak card when Fun mode is off', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await SettingsRepository(db).update((p) => p.copyWith(funMode: false));
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('streak-card')), findsNothing);
  });
}
