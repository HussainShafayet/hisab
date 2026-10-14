import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

const _card = ValueKey('overdrawn-card');

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// Takes [amount] out of [account] with an expense.
Future<void> spend(AppDatabase db, Basics b, int account, int amount) =>
    db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: amount,
        accountId: account,
        categoryId: Value(b.food),
        date: DateTime(2026, 10, 5),
      ),
    );

void main() {
  group('on Home', () {
    testWithDatabase('stays away while every account is zero or more', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(_card), findsNothing);
    });

    testWithDatabase('names the account that is below zero', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, b.cash, 25000);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('1 account is below zero'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey('overdrawn-${b.cash}'))).data,
        '-৳250.00',
      );
    });

    testWithDatabase('counts several accounts and lists the deepest first', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, b.cash, 10000);
      await spend(db, b, b.bkash, 30000);
      await pumpAppWithDatabase(tester, db);

      expect(find.text('2 accounts are below zero'), findsOneWidget);
      final bkash = tester.getTopLeft(
        find.byKey(ValueKey('overdrawn-${b.bkash}')),
      );
      final cash = tester.getTopLeft(
        find.byKey(ValueKey('overdrawn-${b.cash}')),
      );
      expect(bkash.dy, lessThan(cash.dy));
    });

    testWithDatabase('does not count a credit card, which owes on purpose', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      final card = await insertTestAccount(
        db,
        name: 'EBL',
        type: AccountType.creditCard,
      );
      await spend(db, b, card, 99900);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(_card), findsNothing);
    });

    testWithDatabase('does not count an archived account', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, b.cash, 25000);
      await db.accountsDao.setArchived(b.cash, archived: true);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(_card), findsNothing);
    });

    testWithDatabase('leaves when the money is put back', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, b.cash, 25000);
      await pumpAppWithDatabase(tester, db);
      expect(find.byKey(_card), findsOneWidget);

      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.income,
          amount: 30000,
          accountId: b.cash,
          categoryId: Value(b.salary),
          date: DateTime(2026, 10, 6),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_card), findsNothing);
    });

    testWithDatabase('opens the accounts when tapped', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await spend(db, b, b.cash, 25000);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(_card));
      await tester.pumpAndSettle();

      expect(appBarTitle('Accounts'), findsOneWidget);
    });
  });

  group('on the account card', () {
    Account account({
      AccountType type = AccountType.cash,
      bool archived = false,
    }) => Account(
      id: 1,
      name: 'Wallet',
      type: type,
      openingBalance: 0,
      includeInTotal: true,
      isArchived: archived,
    );

    Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: card),
        ),
      ),
    );

    testWidgets('says "Below zero" with a warning', (tester) async {
      await pump(tester, AccountCard(account: account(), balance: -5000));

      expect(find.text('Below zero'), findsOneWidget);
      expect(find.text('Balance'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('says "Balance" at zero and above', (tester) async {
      await pump(tester, AccountCard(account: account(), balance: 0));

      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Below zero'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('says "Owed" for a credit card, with no warning', (
      tester,
    ) async {
      await pump(
        tester,
        AccountCard(
          account: account(type: AccountType.creditCard),
          balance: -5000,
        ),
      );

      expect(find.text('Owed'), findsOneWidget);
      expect(find.text('Below zero'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('does not warn for an archived account', (tester) async {
      await pump(
        tester,
        AccountCard(account: account(archived: true), balance: -5000),
      );

      expect(find.text('Below zero'), findsNothing);
      expect(find.text('Balance'), findsOneWidget);
    });
  });
}
