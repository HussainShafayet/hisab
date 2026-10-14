import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/credit_card_tile.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_rate_service.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/form_actions.dart';
import '../../../helpers/pump_app.dart';

CreditCardStatus status({
  int? usdLimit,
  CardDollars dollars = CardDollars.none,
}) => CreditCardStatus(
  account: Account(
    id: 1,
    name: 'EBL',
    type: AccountType.creditCard,
    openingBalance: 0,
    includeInTotal: true,
    isArchived: false,
    creditLimit: 11120000,
    usdLimit: usdLimit,
  ),
  balance: -2000000,
  dollars: dollars,
);

Future<void> pumpTile(WidgetTester tester, CreditCardStatus card) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreditCardTile(
            card: card,
            today: DateTime(2026, 10, 11),
            onTap: () {},
            onPay: () {},
          ),
        ),
      ),
    );

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  group('the credit card tile', () {
    testWidgets('shows no dollar lines for a taka-only card', (tester) async {
      await pumpTile(tester, status());

      expect(find.byKey(const ValueKey('card-usd-spent-1')), findsNothing);
      expect(find.byKey(const ValueKey('card-usd-due-1')), findsNothing);
    });

    testWidgets('shows what was spent in dollars and what is still due', (
      tester,
    ) async {
      await pumpTile(
        tester,
        status(
          dollars: const CardDollars(
            spent: 14000,
            settled: 4000,
            spentThisMonth: 9000,
            lastRate: 122,
          ),
        ),
      );

      expect(
        textOf(tester, 'card-usd-spent-1'),
        'Spent in dollars this month: \$90.00',
      );
      expect(textOf(tester, 'card-usd-due-1'), 'Dollars still due: \$100.00');
      // No dollar limit, so no "left" line.
      expect(find.byKey(const ValueKey('card-usd-left-1')), findsNothing);
    });

    testWidgets('shows what is left in taka and in dollars', (tester) async {
      await pumpTile(
        tester,
        status(
          usdLimit: 7400,
          dollars: const CardDollars(spent: 5000, lastRate: 122),
        ),
      );

      expect(
        textOf(tester, 'card-usd-left-1'),
        'Left: ৳97,300.00 in taka and \$24.00 in dollars',
      );
      expect(
        textOf(tester, 'card-usd-total-1'),
        'About ৳1,00,228.00 left in all',
      );
    });

    testWidgets('shows both parts before there is a rate, and no total', (
      tester,
    ) async {
      await pumpTile(tester, status(usdLimit: 7400));

      expect(
        textOf(tester, 'card-usd-left-1'),
        'Left: ৳91,200.00 in taka and \$74.00 in dollars',
      );
      expect(find.byKey(const ValueKey('card-usd-total-1')), findsNothing);
    });
  });

  group('the card on the accounts screen', () {
    testWidgets('says the limits instead of a bar when it has two', (
      tester,
    ) async {
      final card = status(usdLimit: 7400);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountCard(account: card.account, balance: card.balance),
          ),
        ),
      );

      expect(
        textOf(tester, 'card-limits-1'),
        'Limits ৳1,11,200.00 and \$74.00',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWithDatabase('shows the bill day, dollars and what is left', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'EBL',
          type: AccountType.creditCard,
          openingBalance: const Value(-2000000),
          creditLimit: const Value(11120000),
          usdLimit: const Value(7400),
          billDueDay: const Value(15),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(
        textOf(tester, 'card-limits-$id'),
        'Limits ৳1,11,200.00 and \$74.00',
      );
      expect(textOf(tester, 'card-due-$id'), 'Bill due 15 Oct');
      expect(
        textOf(tester, 'card-usd-left-$id'),
        'Left: ৳91,200.00 in taka and \$74.00 in dollars',
      );
      expect(find.byKey(ValueKey('pay-bill-$id')), findsOneWidget);
    });

    testWithDatabase('Pay bill opens a transfer for what is owed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      final id = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'EBL',
          type: AccountType.creditCard,
          openingBalance: const Value(-50000),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(find.byKey(ValueKey('pay-bill-$id')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '500');
    });
  });

  group('the transaction form', () {
    Future<int> makeCard(AppDatabase db) => db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'EBL',
        type: AccountType.creditCard,
        creditLimit: const Value(12000000),
      ),
    );

    testWithDatabase('has no dollar field for a cash account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.byKey(const ValueKey('usd-field')), findsNothing);
    });

    testWithDatabase('has a dollar field for a credit card, with the rate', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db);
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      expect(find.byKey(const ValueKey('usd-field')), findsOneWidget);
      expect(find.text('Spent in dollars (optional)'), findsOneWidget);

      await typeAmount(tester, '3050');
      await tester.enterText(find.byKey(const ValueKey('usd-field')), '25');
      await tester.pump();

      expect(find.text('About ৳122.00 for each dollar.'), findsOneWidget);
    });

    testWithDatabase('saves the dollars with the expense', (tester, db) async {
      useTallScreen(tester);
      final card = await makeCard(db);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '3050');
      await tester.enterText(find.byKey(const ValueKey('usd-field')), '25.50');
      await tester.pump();
      await chooseCategory(tester, b.food);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final rows = await db.transactionsDao.getAll();
      expect(rows.single.accountId, card);
      expect(rows.single.amount, 305000);
      expect(rows.single.usdAmount, 2550);
    });

    testWithDatabase('refuses a dollar amount that is not a number', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db);
      final b = await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openAddForm(tester);

      await typeAmount(tester, '3050');
      await tester.enterText(find.byKey(const ValueKey('usd-field')), '0');
      await tester.pump();
      await chooseCategory(tester, b.food);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid dollar amount, like 25 or 25.50.'),
        findsOneWidget,
      );
      expect(await db.transactionsDao.getAll(), isEmpty);
    });

    testWithDatabase('shows the dollars on the saved transaction', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 305000,
        accountId: card,
        categoryId: b.food,
        date: DateTime(2026, 10, 10),
      );
      await db.transactionsDao.updateTransaction(
        (await db.transactionsDao.getAll()).single.copyWith(
          usdAmount: const Value(2500),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('\$25.00'), findsOneWidget);
    });

    testWithDatabase("fills the taka from today's rate when it is empty", (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db);
      await seedBasics(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [
          rateServiceProvider.overrideWithValue(
            FakeRateService(bdtPerUsd: 122.5),
          ),
        ],
      );
      await openAddForm(tester);

      await tester.enterText(find.byKey(const ValueKey('usd-field')), '20');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('usd-rate')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '2450');
      expect(
        find.textContaining('The market rate today is about ৳122.50'),
        findsOneWidget,
      );
    });

    testWithDatabase('keeps a taka amount that was typed already', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db);
      await seedBasics(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [rateServiceProvider.overrideWithValue(FakeRateService())],
      );
      await openAddForm(tester);

      await typeAmount(tester, '2500');
      await tester.enterText(find.byKey(const ValueKey('usd-field')), '20');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('usd-rate')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '2500');
      expect(find.byKey(const ValueKey('usd-rate-note')), findsOneWidget);
    });

    testWithDatabase('asks for the dollars first', (tester, db) async {
      useTallScreen(tester);
      await makeCard(db);
      await seedBasics(db);
      final rates = FakeRateService();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [rateServiceProvider.overrideWithValue(rates)],
      );
      await openAddForm(tester);

      await tester.tap(find.byKey(const ValueKey('usd-rate')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the dollar amount first.'), findsOneWidget);
      expect(rates.calls, 0);
    });

    testWithDatabase('says so when the internet is not there', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await makeCard(db);
      await seedBasics(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [
          rateServiceProvider.overrideWithValue(FakeRateService(fails: true)),
        ],
      );
      await openAddForm(tester);

      await tester.enterText(find.byKey(const ValueKey('usd-field')), '20');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('usd-rate')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Could not get today's rate. Check your internet and try again.",
        ),
        findsOneWidget,
      );
      expect(amountText(tester), isEmpty);
    });
  });
}
