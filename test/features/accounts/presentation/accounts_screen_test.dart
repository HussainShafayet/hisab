import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Future<int> addAccount(
  AppDatabase db,
  String name, {
  AccountType type = AccountType.cash,
  int openingBalance = 0,
  bool includeInTotal = true,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(
    name: name,
    type: type,
    openingBalance: Value(openingBalance),
    includeInTotal: Value(includeInTotal),
  ),
);

void main() {
  testWithDatabase('shows an empty state with a way to add the first account', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Accounts');

    expect(find.text('No accounts yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();

    expect(find.text('New account'), findsOneWidget);
  });

  testWithDatabase('lists accounts with balances and the total', (
    tester,
    db,
  ) async {
    final cash = await addAccount(db, 'Cash', openingBalance: 100000);
    await addAccount(
      db,
      'bKash',
      type: AccountType.mobileBanking,
      openingBalance: 25050,
    );
    await addAccount(
      db,
      'Savings',
      type: AccountType.bank,
      openingBalance: 900000,
      includeInTotal: false,
    );
    final salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
    await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.income,
        amount: 50000,
        accountId: cash,
        categoryId: Value(salary),
        date: DateTime(2026, 10, 1),
      ),
    );

    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Accounts');

    expect(find.text('৳1,500.00'), findsOneWidget); // Cash
    expect(find.text('৳250.50'), findsOneWidget); // bKash
    expect(find.text('৳9,000.00'), findsOneWidget); // Savings
    expect(find.text('Bank · Not in total'), findsOneWidget);
    // 1,500.00 + 250.50, without Savings.
    expect(find.text('৳1,750.50'), findsOneWidget);
    expect(find.text('2 accounts included'), findsOneWidget);
  });

  group('adding an account', () {
    Future<void> openAddForm(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWithDatabase('saves a new account and shows it in the list', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        '  Savings  ',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bank'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '2500.50',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('New account'), findsNothing);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('৳2,500.50'), findsOneWidget);
      expect(find.text('Bank · Not in total'), findsOneWidget);
      // Only Cash counts towards the total.
      expect(find.text('1 account included'), findsOneWidget);
    });

    testWithDatabase('asks for a name', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('New account'), findsOneWidget);
    });

    testWithDatabase('rejects an opening balance that is not a number', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Cash',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '1.234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('valid amount'), findsOneWidget);
      expect(await db.accountsDao.getAll(), isEmpty);
    });

    testWithDatabase('shows the repository error for a duplicate name', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'cash',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(
        find.text('An account named "Cash" already exists.'),
        findsOneWidget,
      );
      expect(find.text('New account'), findsOneWidget);
      expect(await db.accountsDao.getAll(), hasLength(1));
    });
  });

  testWithDatabase('edits an account', (tester, db) async {
    useTallScreen(tester);
    await addAccount(db, 'Cash', openingBalance: 100000);
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Accounts');

    await tester.tap(listRow('Cash'));
    await tester.pumpAndSettle();

    expect(find.text('Edit account'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
          .controller!
          .text,
      'Cash',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Opening balance'),
          )
          .controller!
          .text,
      '1000',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Wallet',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Opening balance'),
      '-20.5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit account'), findsNothing);
    expect(listRow('Wallet'), findsOneWidget);
    expect(listRow('Cash'), findsNothing);
    expect(find.text('-৳20.50'), findsWidgets);
  });

  group('archiving', () {
    testWithDatabase('archives after confirming, with undo', (
      tester,
      db,
    ) async {
      await addAccount(db, 'Cash');
      await addAccount(db, 'Bank', type: AccountType.bank);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive "Cash"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(listRow('Cash'), findsNothing);
      expect(listRow('Bank'), findsOneWidget);
      expect(find.text('Cash archived'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(listRow('Cash'), findsOneWidget);
    });

    testWithDatabase('cancelling the dialog keeps the account', (
      tester,
      db,
    ) async {
      await addAccount(db, 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(listRow('Cash'), findsOneWidget);
      expect((await db.accountsDao.getAll()).single.isArchived, isFalse);
    });

    testWithDatabase('shows archived accounts on request and restores them', (
      tester,
      db,
    ) async {
      final id = await addAccount(db, 'Cash', openingBalance: 5000);
      await db.accountsDao.setArchived(id, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.text('No accounts yet'), findsOneWidget);

      await tester.tap(find.byTooltip('Show archived'));
      await tester.pumpAndSettle();

      expect(listRow('Cash'), findsOneWidget);
      expect(find.text('Cash · Archived'), findsOneWidget);
      // Archived accounts are left out of the total.
      expect(find.text('0 accounts included'), findsOneWidget);

      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Cash · Archived'), findsNothing);
      expect(find.text('1 account included'), findsOneWidget);
    });
  });

  group('adjusting the balance', () {
    testWithDatabase('records the difference and updates the balance', (
      tester,
      db,
    ) async {
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Adjust balance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('currently shows ৳1,000.00'), findsOneWidget);
      // Nothing typed yet, so there is nothing to record.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Adjust'))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextFormField), '1500.50');
      await tester.pump();
      expect(find.text('Records ৳500.50 as income.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Adjust'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust balance'), findsNothing);
      expect(find.text('Recorded ৳500.50 income on Cash'), findsOneWidget);
      expect(find.text('৳1,500.50'), findsWidgets);
    });

    testWithDatabase('previews an expense and a matching balance', (
      tester,
      db,
    ) async {
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Adjust balance'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '400');
      await tester.pump();
      expect(find.text('Records ৳600.00 as an expense.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1000');
      await tester.pump();
      expect(find.text('The balance already matches.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Adjust'))
            .onPressed,
        isNull,
      );
    });

    testWithDatabase('cancel records nothing', (tester, db) async {
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openRowMenu(tester, 'Cash');
      await tester.tap(find.text('Adjust balance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '1');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
    });
  });
}
