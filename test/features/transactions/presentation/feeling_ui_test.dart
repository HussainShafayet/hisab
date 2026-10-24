import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

Finder chip(Feeling f) => find.byKey(ValueKey('feeling-${f.name}'));

void main() {
  testWithDatabase('an expense can be marked as a regret when saved', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openAddForm(tester);

    await typeAmount(tester, '250');
    await chooseCategory(tester, b.food);
    await openMoreDetails(tester);
    await tester.ensureVisible(chip(Feeling.regret));
    await tester.tap(chip(Feeling.regret));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await db.transactionsDao.getBetween(
      DateTime(2000),
      DateTime(2100),
    );
    expect(rows.single.feeling, Feeling.regret);
  });

  testWithDatabase('tapping the chosen feeling again clears it', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openAddForm(tester);

    await typeAmount(tester, '250');
    await chooseCategory(tester, b.food);
    await openMoreDetails(tester);
    await tester.ensureVisible(chip(Feeling.want));
    await tester.tap(chip(Feeling.want));
    await tester.pump();
    await tester.tap(chip(Feeling.want));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await db.transactionsDao.getBetween(
      DateTime(2000),
      DateTime(2100),
    );
    expect(rows.single.feeling, isNull);
  });

  testWithDatabase('the chips are only for expenses', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openAddForm(tester);

    // Folded away until "More details" is opened.
    expect(chip(Feeling.need), findsNothing);
    await openMoreDetails(tester);
    expect(chip(Feeling.need), findsOneWidget);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(chip(Feeling.need), findsNothing);
  });

  group('the regret meter on Home', () {
    testWithDatabase('is not there until something is marked', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('regret-meter')), findsNothing);
    });

    testWithDatabase('shows the month and what Takka thinks', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final repo = TransactionsRepository(db);
      Future<void> spend(int amount, Feeling f, int day) => repo
          .addTransaction(
            TransactionInput(
              type: TransactionType.expense,
              amount: amount,
              accountId: b.cash,
              categoryId: b.food,
              date: DateTime(2026, 10, day, 12),
              feeling: f,
            ),
          )
          .then((_) {});
      await spend(90000, Feeling.need, 3);
      await spend(10000, Feeling.regret, 8);
      // The regret meter sits in the part of Home that starts closed.
      await showHomeExtras(db);
      await pumpAppWithDatabase(tester, db);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('regret-meter')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Regret'), findsOneWidget);
      expect(
        find.text('৳100.00 went on things you regret. Sleep on it next time.'),
        findsOneWidget,
      );
      expect(find.text('3 days since your last regret.'), findsOneWidget);
    });
  });
}
