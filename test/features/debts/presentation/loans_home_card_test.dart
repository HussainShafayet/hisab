import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/pump_app.dart';

// "Now" in widget tests is Sunday 11 October 2026.
Future<int> lend(
  AppDatabase db, {
  String person = 'Rahim',
  DebtDirection direction = DebtDirection.lent,
  int amount = 100000,
  DateTime? dueOn,
}) => DebtsRepository(db).createDebt(
  person: person,
  direction: direction,
  amount: amount,
  openedOn: DateTime(2026, 9, 20, 10),
  dueOn: dueOn,
);

Future<int> card(
  AppDatabase db, {
  int owed = 50000,
  int? day,
  AccountType type = AccountType.creditCard,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(
    name: 'Visa',
    type: type,
    openingBalance: Value(-owed),
    billDueDay: Value(day),
  ),
);

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  final cardFinder = find.byKey(const ValueKey('loans-home-card'));

  testWithDatabase('is not on Home when there is nothing to get or give', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);

    expect(cardFinder, findsNothing);
  });

  testWithDatabase('shows what I will get and what I will give', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await lend(db, amount: 100000);
    await lend(
      db,
      person: 'Karim',
      direction: DebtDirection.borrowed,
      amount: 30000,
    );
    await pumpAppWithDatabase(tester, db);

    expect(cardFinder, findsOneWidget);
    expect(textOf(tester, 'home-to-get'), '৳1,000.00');
    expect(textOf(tester, 'home-to-give'), '৳300.00');
  });

  testWithDatabase('counts credit card bills in what I will give', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await lend(
      db,
      person: 'Karim',
      direction: DebtDirection.borrowed,
      amount: 30000,
    );
    await card(db, owed: 50000);
    await pumpAppWithDatabase(tester, db);

    expect(textOf(tester, 'home-to-give'), '৳800.00');
  });

  testWithDatabase('is shown for a credit card alone', (tester, db) async {
    useTallScreen(tester);
    await card(db, owed: 50000);
    await pumpAppWithDatabase(tester, db);

    expect(cardFinder, findsOneWidget);
    expect(textOf(tester, 'home-to-get'), '৳0.00');
    expect(textOf(tester, 'home-to-give'), '৳500.00');
  });

  testWithDatabase('does not count a debit card', (tester, db) async {
    useTallScreen(tester);
    await card(db, type: AccountType.card);
    await pumpAppWithDatabase(tester, db);

    expect(cardFinder, findsNothing);
  });

  testWithDatabase('points out loans that are late', (tester, db) async {
    useTallScreen(tester);
    await lend(db, dueOn: DateTime(2026, 10, 1));
    await lend(db, person: 'Karim', dueOn: DateTime(2026, 10, 2));
    await pumpAppWithDatabase(tester, db);

    expect(find.text('2 loans are late'), findsOneWidget);
  });

  testWithDatabase('points out a credit card bill that is close', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await card(db, owed: 50000, day: 13);
    await pumpAppWithDatabase(tester, db);

    expect(find.text('Visa: Bill due 13 Oct'), findsOneWidget);
  });

  testWithDatabase('leaves out a card bill that is far away or paid', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await card(db, owed: 50000, day: 25);
    await pumpAppWithDatabase(tester, db);
    expect(find.textContaining('Visa:'), findsNothing);
  });

  testWithDatabase('opens the loans', (tester, db) async {
    useTallScreen(tester);
    await lend(db);
    await pumpAppWithDatabase(tester, db);

    await tester.tap(cardFinder);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Loans')),
      findsOneWidget,
    );
  });
}
