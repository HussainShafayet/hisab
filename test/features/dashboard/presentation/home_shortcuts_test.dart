import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/pump_app.dart';

// "Now" in widget tests is Sunday 11 October 2026.
void main() {
  testWithDatabase('Home has buttons for loans, bazar, split and goals', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);

    for (final key in [
      'shortcut-loans',
      'shortcut-bazar',
      'shortcut-split',
      'shortcut-goals',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const ValueKey('shortcut-alert')), findsNothing);
  });

  testWithDatabase('the Loans button opens the loans screen', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);

    await tester.tap(find.byKey(const ValueKey('shortcut-loans')));
    await tester.pumpAndSettle();

    expect(find.text("I'll get"), findsWidgets);
  });

  testWithDatabase('the Loans button has a red dot when a loan is late', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await DebtsRepository(db).createDebt(
      person: 'Rahim',
      direction: DebtDirection.lent,
      amount: 100000,
      openedOn: DateTime(2026, 9, 1, 10),
      dueOn: DateTime(2026, 10, 1),
    );
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('shortcut-alert')), findsOneWidget);
  });

  testWithDatabase('with no loans Home invites you to add the first one', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('loans-home-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-add-first-loan')));
    await tester.pumpAndSettle();

    expect(find.text('Add loan'), findsWidgets);
  });

  testWithDatabase('with a loan the card has an Add loan button', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await DebtsRepository(db).createDebt(
      person: 'Rahim',
      direction: DebtDirection.lent,
      amount: 100000,
      openedOn: DateTime(2026, 9, 20, 10),
    );
    await pumpAppWithDatabase(tester, db);

    expect(find.byKey(const ValueKey('loans-home-empty')), findsNothing);
    expect(find.byKey(const ValueKey('home-add-loan')), findsOneWidget);
  });
}
