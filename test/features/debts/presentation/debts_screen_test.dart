import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

// "Now" in widget tests is Sunday 11 October 2026.
final opened = DateTime(2026, 9, 20, 10);

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<int> make(
  AppDatabase db, {
  String person = 'Rahim',
  DebtDirection direction = DebtDirection.lent,
  int amount = 100000,
  int paid = 0,
  DateTime? dueOn,
  int? accountId,
}) async {
  final repo = DebtsRepository(db);
  final id = await repo.createDebt(
    person: person,
    direction: direction,
    amount: amount,
    openedOn: opened,
    dueOn: dueOn,
    accountId: accountId,
  );
  if (paid > 0) {
    await repo.addPayment(id, amount: paid, paidOn: DateTime(2026, 10, 1));
  }
  return id;
}

Future<void> openLoans(WidgetTester tester) => openFromMore(tester, 'Loans');

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> openDetail(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(ValueKey('debt-$id')));
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWithDatabase('opens from More, with an empty state to start', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(appBarTitle('Loans'), findsOneWidget);
      expect(find.text('No loans yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect(appBarTitle('New loan'), findsOneWidget);
    });

    testWithDatabase('adds up what is left to get back and to pay back', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, amount: 100000);
      await make(
        db,
        person: 'Karim',
        direction: DebtDirection.borrowed,
        amount: 30000,
        paid: 10000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(textOf(tester, 'to-get-back'), '৳1,000.00');
      expect(textOf(tester, 'to-pay-back'), '৳200.00');
    });

    testWithDatabase(
      'shows each loan with what is left and how far it is paid',
      (tester, db) async {
        useTallScreen(tester);
        final lent = await make(db, amount: 100000, paid: 40000);
        final borrowed = await make(
          db,
          person: 'Karim',
          direction: DebtDirection.borrowed,
          amount: 30000,
        );
        await pumpAppWithDatabase(tester, db);
        await openLoans(tester);

        expect(textOf(tester, 'debt-amount-$lent'), '৳600.00');
        expect(textOf(tester, 'debt-amount-$borrowed'), '৳300.00');
        expect(find.text('Rahim'), findsOneWidget);
        expect(find.text('They owe you'), findsOneWidget);
        expect(find.text('You owe'), findsOneWidget);
        expect(find.text('Paid ৳400.00 of ৳1,000.00'), findsOneWidget);
      },
    );

    testWithDatabase('says when each one is due, and when it is late', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final late = await make(db, person: 'A', dueOn: DateTime(2026, 10, 1));
      final yesterday = await make(
        db,
        person: 'B',
        dueOn: DateTime(2026, 10, 10),
      );
      final today = await make(db, person: 'C', dueOn: DateTime(2026, 10, 11));
      final later = await make(db, person: 'D', dueOn: DateTime(2026, 10, 20));
      final none = await make(db, person: 'E');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(textOf(tester, 'debt-due-$late'), 'Overdue by 10 days');
      expect(textOf(tester, 'debt-due-$yesterday'), 'Overdue by 1 day');
      expect(textOf(tester, 'debt-due-$today'), 'Due today');
      expect(textOf(tester, 'debt-due-$later'), 'Due 20 Oct');
      expect(find.byKey(ValueKey('debt-due-$none')), findsNothing);
      expect(textOf(tester, 'overdue-count'), '2 loans are overdue');
    });

    testWithDatabase('says so when only one is overdue', (tester, db) async {
      useTallScreen(tester);
      await make(db, dueOn: DateTime(2026, 10, 1));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(textOf(tester, 'overdue-count'), '1 loan is overdue');
    });

    testWithDatabase('has no overdue line when nothing is late', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, dueOn: DateTime(2026, 11, 1));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(const ValueKey('overdue-count')), findsNothing);
    });

    testWithDatabase('puts the late ones first', (tester, db) async {
      useTallScreen(tester);
      final fine = await make(db, person: 'Fine', dueOn: DateTime(2026, 12, 1));
      final late = await make(db, person: 'Late', dueOn: DateTime(2026, 10, 1));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      final lateTop = tester.getTopLeft(find.byKey(ValueKey('debt-$late'))).dy;
      final fineTop = tester.getTopLeft(find.byKey(ValueKey('debt-$fine'))).dy;
      expect(lateTop, lessThan(fineTop));
    });

    testWithDatabase('hides settled loans until asked', (tester, db) async {
      useTallScreen(tester);
      final open = await make(db, person: 'Open');
      final done = await make(db, person: 'Done', amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(ValueKey('debt-$open')), findsOneWidget);
      expect(find.byKey(ValueKey('debt-$done')), findsNothing);

      await tapKey(tester, 'show-settled');

      expect(find.byKey(ValueKey('debt-$done')), findsOneWidget);
      expect(textOf(tester, 'debt-due-$done'), 'Settled');
      // Settled loans are not in the totals.
      expect(textOf(tester, 'to-get-back'), '৳1,000.00');
    });

    testWithDatabase('has no settled chip when nothing is settled', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(const ValueKey('show-settled')), findsNothing);
    });

    testWithDatabase('says so when everything is settled', (tester, db) async {
      useTallScreen(tester);
      await make(db, amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.text('Everything is settled.'), findsOneWidget);
      expect(textOf(tester, 'to-get-back'), '৳0.00');
    });
  });

  group('adding a loan', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWithDatabase('saves the person, the amount and the day', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Person'),
        '  Rahim  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '500',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Loans'), findsOneWidget);
      final debt = (await db.debtsDao.getAllDebts()).single;
      expect(debt.person, 'Rahim');
      expect(debt.amount, 50000);
      expect(debt.direction, DebtDirection.lent);
      expect(debt.accountId, isNull);
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
      expect(find.text('Rahim'), findsOneWidget);
    });

    testWithDatabase('explains which way the money went', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);
      expect(
        textOf(tester, 'direction-hint'),
        'I gave money, and the other person will pay it back.',
      );

      await tapKey(tester, 'direction-borrowed');

      expect(
        textOf(tester, 'direction-hint'),
        'I took money, and I will pay it back.',
      );
    });

    testWithDatabase('can be money I borrowed', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await tapKey(tester, 'direction-borrowed');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Person'),
        'Karim',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '250.50',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      final debt = (await db.debtsDao.getAllDebts()).single;
      expect(debt.direction, DebtDirection.borrowed);
      expect(debt.amount, 25050);
      expect(textOf(tester, 'to-pay-back'), '৳250.50');
    });

    testWithDatabase('can move the balance of an account', (tester, db) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Person'),
        'Rahim',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '500',
      );
      await tester.tap(find.byKey(const ValueKey('loan-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect((await db.debtsDao.getAllDebts()).single.accountId, cash);
      final accounts = await AccountsRepository(db).watchAccounts().first;
      expect(accounts.single.balance, -50000);
    });

    testWithDatabase('can have a due day, and lose it again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.text('Pay back by (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Not set'), findsNothing);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);
    });

    testWithDatabase('asks for a name and an amount', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(await db.debtsDao.getAllDebts(), isEmpty);
    });

    testWithDatabase('offers the names already used', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim');
      await make(db, person: 'Salma');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      expect(find.byKey(const ValueKey('person-Rahim')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('person-Salma')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Person'))
            .controller!
            .text,
        'Salma',
      );
      // The name that is typed is not offered again.
      expect(find.byKey(const ValueKey('person-Salma')), findsNothing);
    });
  });

  group('one loan', () {
    testWithDatabase('shows what is left, what was paid and the payments', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(
        db,
        amount: 100000,
        paid: 30000,
        dueOn: DateTime(2026, 10, 1),
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      expect(appBarTitle('Rahim'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳700.00');
      expect(textOf(tester, 'paid-of-total'), 'Paid ৳300.00 of ৳1,000.00');
      expect(textOf(tester, 'due-text'), 'Overdue by 10 days');
      expect(find.text('৳300.00'), findsOneWidget);
    });

    testWithDatabase('says when nothing was paid yet', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      expect(find.byKey(const ValueKey('no-payments')), findsOneWidget);
    });

    testWithDatabase('takes a payment', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      expect(find.text('Money received'), findsOneWidget);
      // The whole of what is left is filled in.
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Amount'))
            .controller!
            .text,
        '1000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '400',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Payment saved.'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳600.00');
      expect(textOf(tester, 'paid-of-total'), 'Paid ৳400.00 of ৳1,000.00');
      expect(await db.debtsDao.getAllPayments(), hasLength(1));
    });

    testWithDatabase('asks "Money paid back" for a loan I took', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');

      expect(find.text('Money paid back'), findsOneWidget);
    });

    testWithDatabase('refuses a payment of more than what is left', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '1500',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, 'payment-error'),
        'That is more than what is left to pay.',
      );
      expect(await db.debtsDao.getAllPayments(), isEmpty);
    });

    testWithDatabase('moves the account balance with the payment', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      // The account the loan used is chosen already.
      await tapKey(tester, 'add-payment');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '400',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final accounts = await AccountsRepository(db).watchAccounts().first;
      expect(accounts.single.balance, -100000 + 40000);
    });

    testWithDatabase('can be marked as paid in one tap', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 25000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'mark-paid');

      expect(find.text('Marked as paid.'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳0.00');
      expect(find.byKey(const ValueKey('add-payment')), findsNothing);
      expect(find.byKey(const ValueKey('mark-paid')), findsNothing);
      expect((await DebtsRepository(db).getDebt(id))!.isSettled, isTrue);
    });

    testWithDatabase('takes a payment back after asking', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 40000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);
      final payment = (await db.debtsDao.getAllPayments()).single;

      await tapKey(tester, 'delete-payment-${payment.id}');
      expect(find.text('Delete this payment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('payment-${payment.id}')), findsNothing);
      expect(textOf(tester, 'remaining'), '৳1,000.00');
    });

    testWithDatabase('keeps the payment when the question is cancelled', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 40000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);
      final payment = (await db.debtsDao.getAllPayments()).single;

      await tapKey(tester, 'delete-payment-${payment.id}');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('payment-${payment.id}')), findsOneWidget);
    });

    testWithDatabase('is deleted with its balance changes, after asking', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'delete-loan');
      expect(find.text('Delete this loan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Back on the list, which is empty again.
      expect(appBarTitle('Loans'), findsOneWidget);
      expect(find.text('No loans yet'), findsOneWidget);
      final accounts = await AccountsRepository(db).watchAccounts().first;
      expect(accounts.single.balance, 0);
    });

    testWithDatabase('can be renamed, and the money stays', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 10000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'edit-loan');
      expect(appBarTitle('Edit loan'), findsOneWidget);
      // Only the name, the due day and the note can change.
      expect(find.byKey(const ValueKey('direction-lent')), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Amount'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Person'))
            .controller!
            .text,
        'Rahim',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Person'),
        'Rahim Uddin',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Rahim Uddin'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳900.00');
    });
  });

  group('in a transaction list', () {
    testWithDatabase('a loan that moved an account is marked as not counted', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await make(db, accountId: cash);
      await pumpAppWithDatabase(tester, db, now: DateTime(2026, 9, 21));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lent to Rahim · not counted in totals'),
        findsOneWidget,
      );
    });
  });
}
