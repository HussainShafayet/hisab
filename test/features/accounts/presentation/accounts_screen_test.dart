import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
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

/// The wallet card of the account called [name].
Finder accountCard(String name) => find.byWidgetPredicate(
  (widget) => widget is AccountCard && widget.account.name == name,
  description: 'AccountCard of "$name"',
);

/// Taps the menu (three dots) of the card of [name] and waits for it to open.
Future<void> openCardMenu(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: accountCard(name),
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await tester.pumpAndSettle();
}

Finder inCard(String name, String text) =>
    find.descendant(of: accountCard(name), matching: find.text(text));

String totalShown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('total-balance'))).data!;

Future<void> toggleArchived(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('show-archived')));
  await tester.pumpAndSettle();
}

void main() {
  testWithDatabase('shows an empty state with a way to add the first account', (
    tester,
    db,
  ) async {
    await pumpAppWithDatabase(tester, db);
    await openFromMore(tester, 'Accounts');

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('total-card')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();

    expect(find.text('New account'), findsOneWidget);
  });

  group('the list', () {
    Future<void> seed(AppDatabase db) async {
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
    }

    testWithDatabase('shows a wallet card with a balance for each account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(inCard('Cash', '৳1,500.00'), findsOneWidget);
      expect(inCard('bKash', '৳250.50'), findsOneWidget);
      expect(inCard('Savings', '৳9,000.00'), findsOneWidget);
      expect(find.text('Bank · Not in total'), findsOneWidget);
    });

    testWithDatabase('shows the total, leaving out what is not counted', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      // 1,500.00 + 250.50, without Savings.
      expect(totalShown(tester), '৳1,750.50');
      expect(find.text('2 accounts included'), findsOneWidget);
    });

    testWithDatabase('breaks the total down by kind of account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('type-total-cash')),
          matching: find.text('৳1,500.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('type-total-mobileBanking')),
          matching: find.text('৳250.50'),
        ),
        findsOneWidget,
      );
      // Savings is not counted, so there is no bank line.
      expect(find.byKey(const ValueKey('type-total-bank')), findsNothing);
    });

    testWithDatabase('has no breakdown when there is only one kind', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 1000);
      await addAccount(db, 'Wallet', openingBalance: 500);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.byKey(const ValueKey('type-total-cash')), findsNothing);
      expect(totalShown(tester), '৳15.00');
    });

    testWithDatabase('shows a negative total in the same card', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(
        db,
        'Card',
        type: AccountType.card,
        openingBalance: -5000,
      );
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(totalShown(tester), '-৳50.00');
    });
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
      await tester.tap(find.byKey(const ValueKey('type-bank')));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '2500.50',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('New account'), findsNothing);
      expect(inCard('Savings', '৳2,500.50'), findsOneWidget);
      expect(find.text('Bank · Not in total'), findsOneWidget);
      // Only Cash counts towards the total.
      expect(find.text('1 account included'), findsOneWidget);
      final saved = (await db.accountsDao.getAll()).last;
      expect(saved.name, 'Savings');
      expect(saved.type, AccountType.bank);
    });

    testWithDatabase('shows how the account will look while it is filled in', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      Finder inPreview(String text) => find.descendant(
        of: find.byKey(const ValueKey('account-preview')),
        matching: find.text(text),
      );
      expect(inPreview('Account name'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'My wallet',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '120',
      );
      await tester.tap(find.byKey(const ValueKey('type-card')));
      await tester.pump();

      expect(inPreview('My wallet'), findsOneWidget);
      expect(inPreview('Card'), findsOneWidget);
      expect(inPreview('৳120.00'), findsOneWidget);
    });

    testWithDatabase('quick picks for the kind fill in the name', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openAddForm(tester);

      // Cash is the kind to start with.
      expect(find.byKey(const ValueKey('suggestion-Wallet')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-bKash')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('type-mobileBanking')));
      await tester.pump();
      expect(find.byKey(const ValueKey('suggestion-Wallet')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('suggestion-bKash')));
      await tester.pump();

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
            .controller!
            .text,
        'bKash',
      );
      // The name that was picked is not offered again.
      expect(find.byKey(const ValueKey('suggestion-bKash')), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      final saved = (await db.accountsDao.getAll()).single;
      expect(saved.name, 'bKash');
      expect(saved.type, AccountType.mobileBanking);
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

  group('editing an account', () {
    testWithDatabase('opens with what was saved and saves the changes', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(accountCard('Cash'));
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
      // No quick picks when editing.
      expect(find.byKey(const ValueKey('suggestion-Wallet')), findsNothing);

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
      expect(accountCard('Wallet'), findsOneWidget);
      expect(accountCard('Cash'), findsNothing);
      expect(inCard('Wallet', '-৳20.50'), findsOneWidget);
    });

    testWithDatabase('the kind of the account is marked', (tester, db) async {
      useTallScreen(tester);
      await addAccount(db, 'Savings', type: AccountType.bank);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await tester.tap(accountCard('Savings'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('type-bank')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('type-cash')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );
    });
  });

  group('archiving', () {
    testWithDatabase('archives after confirming, with undo', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash');
      await addAccount(db, 'Bank', type: AccountType.bank);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openCardMenu(tester, 'Cash');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive "Cash"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(accountCard('Cash'), findsNothing);
      expect(accountCard('Bank'), findsOneWidget);
      expect(find.text('Cash archived'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(accountCard('Cash'), findsOneWidget);
    });

    testWithDatabase('cancelling the dialog keeps the account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openCardMenu(tester, 'Cash');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(accountCard('Cash'), findsOneWidget);
      expect((await db.accountsDao.getAll()).single.isArchived, isFalse);
    });

    testWithDatabase('shows archived accounts on request and restores them', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await addAccount(db, 'Cash', openingBalance: 5000);
      await db.accountsDao.setArchived(id, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      expect(find.text('No accounts yet'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('show-archived')))
            .selected,
        isFalse,
      );

      await toggleArchived(tester);

      expect(accountCard('Cash'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('show-archived')))
            .selected,
        isTrue,
      );
      // Archived accounts are left out of the total.
      expect(find.text('0 accounts included'), findsOneWidget);

      await openCardMenu(tester, 'Cash');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsNothing);
      expect(find.text('1 account included'), findsOneWidget);
    });

    testWithDatabase('hides them again when the chip is turned off', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash');
      final old = await addAccount(db, 'Old bank', type: AccountType.bank);
      await db.accountsDao.setArchived(old, archived: true);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      expect(accountCard('Old bank'), findsNothing);

      await toggleArchived(tester);
      expect(accountCard('Old bank'), findsOneWidget);

      await toggleArchived(tester);
      expect(accountCard('Old bank'), findsNothing);
      expect(accountCard('Cash'), findsOneWidget);
    });
  });

  group('adjusting the balance', () {
    testWithDatabase('records the difference and updates the balance', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');

      await openCardMenu(tester, 'Cash');
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
      expect(inCard('Cash', '৳1,500.50'), findsOneWidget);
    });

    testWithDatabase('previews an expense and a matching balance', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openCardMenu(tester, 'Cash');
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
      useTallScreen(tester);
      await addAccount(db, 'Cash', openingBalance: 100000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Accounts');
      await openCardMenu(tester, 'Cash');
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
