import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

String shareOf(WidgetTester tester, String name) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey('split-share-$name')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

Future<void> addFriend(WidgetTester tester, String name) async {
  await enter(tester, 'split-friend-name', name);
  await tapKey(tester, 'split-add-friend');
}

void main() {
  testWithDatabase('opens from the Loans screen', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Loans');

    await tapKey(tester, 'split-bill');

    expect(find.text('Split a bill'), findsWidgets);
    expect(find.byKey(const ValueKey('split-total')), findsOneWidget);
  });

  testWithDatabase('shares the bill equally as friends are added', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');

    await enter(tester, 'split-total', '1200');
    await addFriend(tester, 'Rahim');
    expect(shareOf(tester, 'rahim'), '600');
    expect(textOf(tester, 'split-mine'), 'Your part: ৳600.00');

    await addFriend(tester, 'Karim');
    expect(shareOf(tester, 'rahim'), '400');
    expect(shareOf(tester, 'karim'), '400');
    expect(textOf(tester, 'split-mine'), 'Your part: ৳400.00');

    await tapKey(tester, 'split-remove-karim');
    expect(shareOf(tester, 'rahim'), '600');
  });

  testWithDatabase('lets a part be changed, and goes back to equal', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');
    await enter(tester, 'split-total', '1200');
    await addFriend(tester, 'Rahim');
    await addFriend(tester, 'Karim');

    await enter(tester, 'split-share-rahim', '700');

    expect(textOf(tester, 'split-mine'), 'Your part: ৳100.00');
    expect(find.byKey(const ValueKey('split-equal')), findsOneWidget);

    await tapKey(tester, 'split-equal');
    expect(shareOf(tester, 'rahim'), '400');
    expect(find.byKey(const ValueKey('split-equal')), findsNothing);
  });

  testWithDatabase('warns when the parts are more than the bill', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');
    await enter(tester, 'split-total', '1000');
    await addFriend(tester, 'Rahim');

    await enter(tester, 'split-share-rahim', '1500');

    expect(
      textOf(tester, 'split-mine'),
      'The parts add up to more than the bill.',
    );
  });

  testWithDatabase('saves your part as an expense and loans to the friends', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');

    await enter(tester, 'split-title', 'Lunch');
    await enter(tester, 'split-total', '1200');
    await tapKey(tester, 'split-category');
    await tester.tap(find.byKey(ValueKey('category-option-${b.food}')));
    await tester.pumpAndSettle();
    await addFriend(tester, 'Rahim');
    await addFriend(tester, 'Karim');
    await tapKey(tester, 'split-save');

    final expense = (await db.transactionsDao.getAll()).firstWhere(
      (t) => !t.isAdjustment,
    );
    expect(expense.amount, 40000);
    expect(expense.categoryId, b.food);
    final debts = await DebtsRepository(db).watchDebts().first;
    expect(debts.map((d) => d.debt.person).toSet(), {'Rahim', 'Karim'});
    expect(debts.every((d) => d.debt.amount == 40000), isTrue);
    expect(debts.every((d) => d.debt.direction == DebtDirection.lent), isTrue);
    expect(find.text('Split saved. Your part is ৳400.00.'), findsOneWidget);
  });

  testWithDatabase('needs a category and a friend', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');
    await enter(tester, 'split-total', '1200');

    await tapKey(tester, 'split-save');
    expect(find.text('Choose a category.'), findsOneWidget);
    expect(await db.transactionsDao.getAll(), isEmpty);
  });

  testWithDatabase('offers the people from your loans', (tester, db) async {
    useTallScreen(tester);
    await seedBasics(db);
    await DebtsRepository(db).createDebt(
      person: 'Salma',
      direction: DebtDirection.lent,
      amount: 5000,
      openedOn: DateTime(2026, 10, 1),
    );
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Split a bill');
    await enter(tester, 'split-total', '900');

    await tapKey(tester, 'split-suggest-salma');

    expect(shareOf(tester, 'salma'), '450');
  });
}
