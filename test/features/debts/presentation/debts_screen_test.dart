import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/form_actions.dart';
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

Future<int> makeCard(
  AppDatabase db, {
  String name = 'Visa',
  int owed = 50000,
  int? limit = 200000,
  int? day = 15,
}) => db.accountsDao.insertAccount(
  AccountsCompanion.insert(
    name: name,
    type: AccountType.creditCard,
    openingBalance: Value(-owed),
    creditLimit: Value(limit),
    billDueDay: Value(day),
  ),
);

Future<void> openLoans(WidgetTester tester) => openFromMore(tester, 'Loans');

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// Taps the "I'll give" tab.
Future<void> showGive(WidgetTester tester) => tapKey(tester, 'tab-give');

/// Taps the "People" tab.
Future<void> showPeople(WidgetTester tester) => tapKey(tester, 'tab-people');

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> openDetail(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(ValueKey('debt-$id')));
  await tester.pumpAndSettle();
}

Future<void> longPressLoan(WidgetTester tester, int id) async {
  await tester.longPress(find.byKey(ValueKey('debt-$id')));
  await tester.pumpAndSettle();
}

Future<void> swipeLoan(WidgetTester tester, int id, Offset offset) async {
  await tester.fling(find.byKey(ValueKey('swipe-$id')), offset, 1500);
  await tester.pumpAndSettle();
}

Future<void> enterField(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, label), text);

String fieldText(WidgetTester tester, String label) => tester
    .widget<TextFormField>(find.widgetWithText(TextFormField, label))
    .controller!
    .text;

Future<int> balanceOf(AppDatabase db, int accountId) async {
  final accounts = await AccountsRepository(db).watchAccounts().first;
  return accounts.firstWhere((a) => a.account.id == accountId).balance;
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

    testWithDatabase('adds up what I will get and what I will give', (
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

    testWithDatabase('shows the loans that go each way in their own tab', (
      tester,
      db,
    ) async {
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

      // The first tab is the money I will get.
      expect(textOf(tester, 'debt-amount-$lent'), '৳600.00');
      expect(find.byKey(ValueKey('debt-$borrowed')), findsNothing);
      expect(find.text('Rahim'), findsOneWidget);
      expect(find.text('Owes you'), findsOneWidget);
      expect(find.text('Paid ৳400.00 of ৳1,000.00'), findsOneWidget);

      await showGive(tester);

      expect(textOf(tester, 'debt-amount-$borrowed'), '৳300.00');
      expect(find.byKey(ValueKey('debt-$lent')), findsNothing);
      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
    });

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

      expect(textOf(tester, 'debt-due-$late'), '10 days late');
      expect(textOf(tester, 'debt-due-$yesterday'), '1 day late');
      expect(textOf(tester, 'debt-due-$today'), 'Due today');
      expect(textOf(tester, 'debt-due-$later'), 'Due 20 Oct');
      expect(find.byKey(ValueKey('debt-due-$none')), findsNothing);
      expect(textOf(tester, 'overdue-count'), '2 loans are late');
    });

    testWithDatabase('says so when only one is late', (tester, db) async {
      useTallScreen(tester);
      await make(db, dueOn: DateTime(2026, 10, 1));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(textOf(tester, 'overdue-count'), '1 loan is late');
    });

    testWithDatabase('has no late line when nothing is late', (
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

    testWithDatabase('hides the paid ones until asked', (tester, db) async {
      useTallScreen(tester);
      final open = await make(db, person: 'Open');
      final done = await make(db, person: 'Done', amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(ValueKey('debt-$open')), findsOneWidget);
      expect(find.byKey(ValueKey('debt-$done')), findsNothing);

      await tapKey(tester, 'show-settled');

      expect(find.byKey(ValueKey('debt-$done')), findsOneWidget);
      expect(textOf(tester, 'debt-due-$done'), 'All paid');
      // Paid loans are not in the totals.
      expect(textOf(tester, 'to-get-back'), '৳1,000.00');
    });

    testWithDatabase('has no chip for paid ones when none is paid', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.byKey(const ValueKey('show-settled')), findsNothing);
    });

    testWithDatabase('says so when everything is paid', (tester, db) async {
      useTallScreen(tester);
      await make(db, amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(find.text('Everything is paid.'), findsOneWidget);
      expect(textOf(tester, 'to-get-back'), '৳0.00');
    });

    testWithDatabase('says so when a tab has nothing', (tester, db) async {
      useTallScreen(tester);
      await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      expect(textOf(tester, 'list-empty'), 'Nobody owes you anything.');

      await make(db, person: 'Other');
      await showPeople(tester);
      await tapKey(tester, 'tab-get');
      await showGive(tester);
      expect(find.byKey(const ValueKey('list-empty')), findsNothing);
    });
  });

  group('quick actions on the list', () {
    testWithDatabase('a long press offers what can be done', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await longPressLoan(tester, id);

      expect(find.byKey(const ValueKey('loan-action-payment')), findsOneWidget);
      expect(find.byKey(const ValueKey('loan-action-paid')), findsOneWidget);
      expect(find.byKey(const ValueKey('loan-action-remind')), findsOneWidget);
      expect(find.byKey(const ValueKey('loan-action-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('loan-action-delete')), findsOneWidget);
    });

    testWithDatabase('a reminder is only offered for money I will get', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      await longPressLoan(tester, id);

      expect(find.byKey(const ValueKey('loan-action-remind')), findsNothing);
      expect(find.byKey(const ValueKey('loan-action-paid')), findsOneWidget);
    });

    testWithDatabase('"All paid" pays what is left, and can be undone', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 25000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-paid');

      expect(find.text('All paid.'), findsOneWidget);
      expect((await DebtsRepository(db).getDebt(id))!.isSettled, isTrue);
      // It is paid, so it leaves the list.
      expect(find.byKey(ValueKey('debt-$id')), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect((await DebtsRepository(db).getDebt(id))!.paid, 25000);
      expect(find.byKey(ValueKey('debt-$id')), findsOneWidget);
    });

    testWithDatabase('a payment can be added from the sheet', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-payment');
      await enterField(tester, 'Amount', '400');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Payment saved.'), findsOneWidget);
      expect(textOf(tester, 'debt-amount-$id'), '৳600.00');
    });

    testWithDatabase('swiping left marks it all paid', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await swipeLoan(tester, id, const Offset(-500, 0));

      expect(find.text('All paid.'), findsOneWidget);
      expect((await DebtsRepository(db).getDebt(id))!.isSettled, isTrue);
    });

    testWithDatabase('swiping right asks for a payment', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await swipeLoan(tester, id, const Offset(500, 0));

      expect(find.text('They paid me'), findsOneWidget);
      // The loan stays on the list.
      expect(find.byKey(ValueKey('debt-$id')), findsOneWidget);
    });

    testWithDatabase('a reminder opens the share sheet with a message', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFileGateway();
      final id = await make(db, amount: 50000, dueOn: DateTime(2026, 10, 1));
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-remind');

      expect(gateway.sharedTexts, [
        'Hi Rahim, a quick reminder about the ৳500.00 you owe me, which was '
            'due on 1 Oct. Please send it when you can. Thanks!',
      ]);
    });

    testWithDatabase('a reminder without a due day does not mention one', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFileGateway();
      final id = await make(db, amount: 50000);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-remind');

      expect(gateway.sharedTexts, [
        'Hi Rahim, a quick reminder about the ৳500.00 you owe me. Please send '
            'it when you can. Thanks!',
      ]);
    });

    testWithDatabase('says so when the share sheet cannot open', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFileGateway()..failure = StateError('no share');
      final id = await make(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-remind');

      expect(find.text('Could not open the share sheet.'), findsOneWidget);
    });

    testWithDatabase('a loan can be deleted from the sheet, after asking', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await longPressLoan(tester, id);
      await tapKey(tester, 'loan-action-delete');
      expect(find.text('Delete this loan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await db.debtsDao.getAllDebts(), isEmpty);
    });
  });

  group('people', () {
    testWithDatabase('lists each person with what is left between us', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim', amount: 100000);
      await make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 30000,
      );
      await make(
        db,
        person: 'Karim',
        direction: DebtDirection.borrowed,
        amount: 20000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(textOf(tester, 'person-net-rahim'), '৳700.00');
      expect(find.text('Owes you · 2 loans'), findsOneWidget);
      expect(textOf(tester, 'person-net-karim'), '৳200.00');
      expect(find.text('You owe · 1 loan'), findsOneWidget);
    });

    testWithDatabase('puts "Rahim" and " rahim " together', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim');
      await make(db, person: 'rahim', amount: 50000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(find.byKey(const ValueKey('person-tile-rahim')), findsOneWidget);
      expect(textOf(tester, 'person-net-rahim'), '৳1,500.00');
    });

    testWithDatabase('says so when a person is late', (tester, db) async {
      useTallScreen(tester);
      await make(db, dueOn: DateTime(2026, 10, 1));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(find.text('Owes you · 1 loan · Late'), findsOneWidget);
    });

    testWithDatabase('says "All paid" for a person with nothing left', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(find.text('All paid'), findsOneWidget);
      expect(textOf(tester, 'person-net-rahim'), '');
    });

    testWithDatabase('says so when the two sides cancel out', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, amount: 30000);
      await make(db, direction: DebtDirection.borrowed, amount: 30000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(find.text('Even · 2 loans'), findsOneWidget);
    });

    testWithDatabase('has a note when there is nobody yet', (tester, db) async {
      useTallScreen(tester);
      await makeCard(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);

      expect(
        find.text('People you lend to or borrow from show up here.'),
        findsOneWidget,
      );
    });

    testWithDatabase('opens everything with one person', (tester, db) async {
      useTallScreen(tester);
      final lent = await make(db, person: 'Rahim', amount: 100000);
      final borrowed = await make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 30000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-rahim');

      expect(appBarTitle('Rahim'), findsOneWidget);
      expect(find.text('Rahim owes you'), findsOneWidget);
      expect(textOf(tester, 'person-total'), '৳700.00');
      expect(
        textOf(tester, 'person-both-ways'),
        'Rahim owes you ৳1,000.00, you owe ৳300.00',
      );
      expect(find.byKey(ValueKey('debt-$lent')), findsOneWidget);
      expect(find.byKey(ValueKey('debt-$borrowed')), findsOneWidget);
      expect(find.text('Lent on 20 Sep 2026'), findsOneWidget);
      expect(find.text('Borrowed on 20 Sep 2026'), findsOneWidget);
    });

    testWithDatabase('says who owes whom when I owe', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Karim', direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-karim');

      expect(find.text('You owe Karim'), findsOneWidget);
      expect(find.byKey(const ValueKey('remind-person')), findsNothing);
      expect(find.byKey(const ValueKey('person-both-ways')), findsNothing);
    });

    testWithDatabase('sends a reminder for what is left between us', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFileGateway();
      await make(db, person: 'Rahim', amount: 100000);
      await make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 30000,
      );
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-rahim');

      await tapKey(tester, 'remind-person');

      expect(gateway.sharedTexts, [
        'Hi Rahim, a quick reminder about the ৳700.00 you owe me. Please send '
            'it when you can. Thanks!',
      ]);
    });

    testWithDatabase('adds a loan with the name filled in', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-rahim');

      await tapKey(tester, 'add-loan-for-person');

      expect(appBarTitle('New loan'), findsOneWidget);
      expect(fieldText(tester, 'Name'), 'Rahim');
    });

    testWithDatabase('shows paid loans last', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim', amount: 5000, paid: 5000);
      final open = await make(db, person: 'Rahim');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-rahim');

      expect(find.byKey(ValueKey('debt-$open')), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    });
  });

  group('setting off', () {
    Future<int> twoWays(AppDatabase db) async {
      await make(db, person: 'Rahim', amount: 100000);
      return make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 30000,
      );
    }

    Future<void> openRahim(WidgetTester tester) async {
      await openLoans(tester);
      await showPeople(tester);
      await tapKey(tester, 'person-tile-rahim');
    }

    testWithDatabase('is offered when the money goes both ways', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await twoWays(db);
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      expect(find.byKey(const ValueKey('set-off')), findsOneWidget);
    });

    testWithDatabase('is not offered when the money goes one way', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim');
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      expect(find.byKey(const ValueKey('set-off')), findsNothing);
    });

    testWithDatabase('asks first, saying what is left after', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await twoWays(db);
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      await tapKey(tester, 'set-off');

      expect(find.text('Set off ৳300.00 on both sides?'), findsOneWidget);
      expect(
        find.text(
          'This takes ৳300.00 off both sides. Account balances do not '
          'change. Then Rahim will owe you ৳700.00.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await db.debtsDao.getAllPayments(), isEmpty);
    });

    testWithDatabase('leaves only the difference, and can be undone', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await twoWays(db);
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      await tapKey(tester, 'set-off');
      await tester.tap(find.widgetWithText(FilledButton, 'Set off'));
      await tester.pumpAndSettle();

      expect(find.text('Set off ৳300.00.'), findsOneWidget);
      expect(textOf(tester, 'person-total'), '৳700.00');
      // Only one side is left, so there is nothing more to set off.
      expect(find.byKey(const ValueKey('person-both-ways')), findsNothing);
      expect(find.byKey(const ValueKey('set-off')), findsNothing);
      expect(await db.debtsDao.getAllPayments(), hasLength(2));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(await db.debtsDao.getAllPayments(), isEmpty);
      expect(find.byKey(const ValueKey('set-off')), findsOneWidget);
    });

    testWithDatabase('says who owes whom when I owe more', (tester, db) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim', amount: 10000);
      await make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 40000,
      );
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      await tapKey(tester, 'set-off');

      expect(
        find.textContaining('Then you will owe Rahim ৳300.00.'),
        findsOneWidget,
      );
    });

    testWithDatabase('says so when the two sides are the same', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await make(db, person: 'Rahim', amount: 30000);
      await make(
        db,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 30000,
      );
      await pumpAppWithDatabase(tester, db);
      await openRahim(tester);

      await tapKey(tester, 'set-off');

      expect(
        find.textContaining('Then you and Rahim will be even.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Set off'));
      await tester.pumpAndSettle();
      expect(find.text('Rahim owes you'), findsNothing);
      expect(find.text('All paid'), findsWidgets);
    });
  });

  group('credit cards', () {
    testWithDatabase('are on the "I\'ll give" side with what is owed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 50000, limit: 200000, day: 15);
      await make(db, person: 'Karim', direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      // Nothing on the "get" side, and the total counts the card.
      expect(find.byKey(ValueKey('card-$card')), findsNothing);
      expect(textOf(tester, 'to-pay-back'), '৳1,500.00');
      expect(
        textOf(tester, 'give-split'),
        '৳1,000.00 to people and ৳500.00 on credit cards',
      );

      await showGive(tester);

      expect(find.text('Credit cards'), findsOneWidget);
      expect(find.byKey(ValueKey('card-$card')), findsOneWidget);
      expect(find.text('Visa'), findsOneWidget);
      expect(textOf(tester, 'balance-$card'), '৳500.00');
      expect(find.text('Owed'), findsOneWidget);
      expect(textOf(tester, 'limit-left'), '৳1,500.00 left to spend');
      expect(textOf(tester, 'card-due-$card'), 'Bill due 15 Oct');
      // The people come after the cards.
      expect(find.text('Karim'), findsOneWidget);
    });

    testWithDatabase('say when the bill is due today or tomorrow', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final today = await makeCard(db, name: 'Today', day: 11);
      final tomorrow = await makeCard(db, name: 'Tomorrow', day: 12);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      expect(textOf(tester, 'card-due-$today'), 'Bill due today');
      expect(textOf(tester, 'card-due-$tomorrow'), 'Bill due tomorrow');
    });

    testWithDatabase('ask for a bill day when none is set', (tester, db) async {
      useTallScreen(tester);
      final card = await makeCard(db, day: null);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      expect(
        textOf(tester, 'card-due-$card'),
        'Set a bill day to get reminders',
      );
    });

    testWithDatabase('with nothing owed have nothing to pay', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final card = await makeCard(db, owed: 0);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      expect(textOf(tester, 'card-due-$card'), 'Nothing owed');
      expect(find.byKey(ValueKey('pay-bill-$card')), findsNothing);
      expect(textOf(tester, 'to-pay-back'), '৳0.00');
    });

    testWithDatabase('go over the limit and say so', (tester, db) async {
      useTallScreen(tester);
      await makeCard(db, owed: 250000, limit: 200000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      expect(textOf(tester, 'limit-left'), 'Over the limit by ৳500.00');
    });

    testWithDatabase('do not count archived cards or debit cards', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final old = await makeCard(db, name: 'Old');
      await AccountsRepository(db).archiveAccount(old);
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'Debit',
          type: AccountType.card,
          openingBalance: const Value(-9000),
        ),
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      // Nothing to get or give, so the empty state is shown.
      expect(find.text('No loans yet'), findsOneWidget);
    });

    testWithDatabase('"Pay bill" starts a transfer for what is owed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Bank');
      final card = await makeCard(db, owed: 50000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      await tapKey(tester, 'pay-bill-$card');

      expect(appBarTitle('Add transaction'), findsOneWidget);
      expect(amountText(tester), '500');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('to-field')),
          matching: find.text('Visa'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('from-field')),
          matching: find.text('Bank'),
        ),
        findsOneWidget,
      );
      // Paid in full, the card owes nothing after this.
      expect(textOf(tester, 'balance-after-$card'), '৳0.00');
    });

    testWithDatabase('open the account when tapped', (tester, db) async {
      useTallScreen(tester);
      final card = await makeCard(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      await tapKey(tester, 'card-$card');

      expect(appBarTitle('Edit account'), findsOneWidget);
      expect(find.byKey(const ValueKey('credit-limit')), findsOneWidget);
    });
  });

  group('adding a loan', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWithDatabase('saves the name, the amount and the day', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      await enterField(tester, 'Name', '  Rahim  ');
      await enterField(tester, 'Amount', '500');
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

    testWithDatabase('has two big choices that say which way the money went', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      expect(find.text('I gave money'), findsOneWidget);
      expect(find.text('They will pay me back'), findsOneWidget);
      expect(find.text('I took money'), findsOneWidget);
      expect(find.text('I will pay it back'), findsOneWidget);
    });

    testWithDatabase('can be money I took', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await tapKey(tester, 'direction-borrowed');
      await enterField(tester, 'Name', 'Karim');
      await enterField(tester, 'Amount', '250.50');
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      final debt = (await db.debtsDao.getAllDebts()).single;
      expect(debt.direction, DebtDirection.borrowed);
      expect(debt.amount, 25050);
      expect(textOf(tester, 'to-pay-back'), '৳250.50');
    });

    testWithDatabase('can update an account too, and shows what it will hold', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      // Off to begin with: no account card.
      expect(find.byKey(ValueKey('loan-account-$cash')), findsNothing);

      await enterField(tester, 'Name', 'Rahim');
      await enterField(tester, 'Amount', '500');
      await tapKey(tester, 'loan-account-switch');

      expect(find.byKey(ValueKey('loan-account-$cash')), findsOneWidget);
      expect(find.text('Comes out of'), findsOneWidget);
      expect(textOf(tester, 'balance-after-$cash'), '-৳500.00');

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect((await db.debtsDao.getAllDebts()).single.accountId, cash);
      expect(await balanceOf(db, cash), -50000);
    });

    testWithDatabase('money I took goes into the account', (tester, db) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await tapKey(tester, 'direction-borrowed');
      await enterField(tester, 'Name', 'Karim');
      await enterField(tester, 'Amount', '300');
      await tapKey(tester, 'loan-account-switch');

      expect(find.text('Goes into'), findsOneWidget);
      expect(textOf(tester, 'balance-after-$cash'), '৳300.00');
    });

    testWithDatabase('can switch to another account', (tester, db) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final bkash = await insertTestAccount(db, name: 'bKash');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await enterField(tester, 'Name', 'Rahim');
      await enterField(tester, 'Amount', '100');
      await tapKey(tester, 'loan-account-switch');
      expect(find.byKey(ValueKey('loan-account-$cash')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('loan-account-$cash')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'account-option-$bkash');
      expect(find.byKey(ValueKey('loan-account-$bkash')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();
      expect((await db.debtsDao.getAllDebts()).single.accountId, bkash);
    });

    testWithDatabase('turning the switch off forgets the account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      await enterField(tester, 'Name', 'Rahim');
      await enterField(tester, 'Amount', '100');
      await tapKey(tester, 'loan-account-switch');
      await tapKey(tester, 'loan-account-switch');

      expect(find.byKey(ValueKey('loan-account-$cash')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();
      expect((await db.debtsDao.getAllDebts()).single.accountId, isNull);
    });

    testWithDatabase('keeps the date, pay back date and note under "More"', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);

      expect(find.text('Pay back date (optional)'), findsNothing);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();

      expect(find.text('Pay back date (optional)'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Note'), findsOneWidget);
    });

    testWithDatabase('can have a pay back date, and lose it again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openForm(tester);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.text('Pay back date (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Not set'), findsNothing);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);
    });

    testWithDatabase('asks to allow reminders when there is a pay back date', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final scheduler = FakeReminderScheduler();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );
      await openLoans(tester);
      await openForm(tester);
      await enterField(tester, 'Name', 'Rahim');
      await enterField(tester, 'Amount', '100');
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay back date (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final before = scheduler.permissionRequests;

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, before + 1);
      // And the new loan is on the schedule.
      expect(
        scheduler.scheduled.map((r) => r.title),
        contains('Loan due today'),
      );
    });

    testWithDatabase('does not ask when there is no pay back date', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final scheduler = FakeReminderScheduler();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );
      await openLoans(tester);
      await openForm(tester);
      await enterField(tester, 'Name', 'Rahim');
      await enterField(tester, 'Amount', '100');
      final before = scheduler.permissionRequests;

      await tester.tap(find.widgetWithText(FilledButton, 'Add loan'));
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, before);
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

      expect(fieldText(tester, 'Name'), 'Salma');
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
      expect(find.text('left to get back'), findsOneWidget);
      expect(textOf(tester, 'paid-of-total'), 'Paid ৳300.00 of ৳1,000.00');
      expect(textOf(tester, 'due-text'), '10 days late');
      expect(find.text('Lent on 20 Sep 2026'), findsOneWidget);
      expect(find.text('৳300.00'), findsOneWidget);
    });

    testWithDatabase('says "left to pay back" for money I took', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      expect(find.text('left to pay back'), findsOneWidget);
      expect(find.text('Borrowed on 20 Sep 2026'), findsOneWidget);
    });

    testWithDatabase('says when nothing was paid yet', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      expect(find.byKey(const ValueKey('no-payments')), findsOneWidget);
      expect(find.text('No payments yet.'), findsOneWidget);
    });

    testWithDatabase('takes a payment', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      expect(find.text('They paid me'), findsOneWidget);
      // The whole of what is left is filled in.
      expect(fieldText(tester, 'Amount'), '1000');
      await enterField(tester, 'Amount', '400');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Payment saved.'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳600.00');
      expect(textOf(tester, 'paid-of-total'), 'Paid ৳400.00 of ৳1,000.00');
      expect(await db.debtsDao.getAllPayments(), hasLength(1));
    });

    testWithDatabase('asks "I paid them" for a loan I took', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');

      expect(find.text('I paid them'), findsOneWidget);
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
      await enterField(tester, 'Amount', '1500');
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
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('payment-account-switch')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Goes into'), findsOneWidget);
      await enterField(tester, 'Amount', '400');
      await tester.pump();
      // 1000 went out, 400 comes back.
      expect(textOf(tester, 'balance-after-$cash'), '-৳600.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await balanceOf(db, cash), -100000 + 40000);
    });

    testWithDatabase('can leave the account alone for one payment', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      await tapKey(tester, 'payment-account-switch');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await balanceOf(db, cash), -100000);
      expect(await db.debtsDao.getAllPayments(), hasLength(1));
    });

    testWithDatabase('can be marked all paid in one tap, and undone', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 25000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'mark-paid');

      expect(find.text('All paid.'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳0.00');
      expect(find.byKey(const ValueKey('add-payment')), findsNothing);
      expect(find.byKey(const ValueKey('mark-paid')), findsNothing);
      expect((await DebtsRepository(db).getDebt(id))!.isSettled, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'remaining'), '৳750.00');
      expect(find.byKey(const ValueKey('mark-paid')), findsOneWidget);
    });

    testWithDatabase('can send a reminder when I am the one waiting', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final gateway = FakeFileGateway();
      final id = await make(db, amount: 100000, paid: 40000);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'remind');

      expect(gateway.sharedTexts.single, contains('৳600.00'));
      expect(gateway.sharedTexts.single, startsWith('Hi Rahim,'));
    });

    testWithDatabase('has no reminder for money I took or a paid loan', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final borrowed = await make(
        db,
        person: 'Karim',
        direction: DebtDirection.borrowed,
      );
      final paid = await make(db, person: 'Salma', amount: 5000, paid: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, borrowed);
      expect(find.byKey(const ValueKey('remind')), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'tab-get');
      await tapKey(tester, 'show-settled');
      await openDetail(tester, paid);
      expect(find.byKey(const ValueKey('remind')), findsNothing);
    });

    testWithDatabase('links to everything with the person when there is more', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final first = await make(db, person: 'Rahim');
      await make(db, person: 'rahim', amount: 5000);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, first);

      await tapKey(tester, 'see-person');

      expect(appBarTitle('Rahim'), findsOneWidget);
      expect(textOf(tester, 'person-total'), '৳1,050.00');
    });

    testWithDatabase('has no such link for a person with one loan', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      expect(find.byKey(const ValueKey('see-person')), findsNothing);
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
      expect(await balanceOf(db, cash), 0);
    });
  });

  group('changing a loan', () {
    Future<void> openEdit(WidgetTester tester, int id) async {
      await openLoans(tester);
      await openDetail(tester, id);
      await tapKey(tester, 'edit-loan');
    }

    testWithDatabase('starts with everything as it is', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      expect(appBarTitle('Edit loan'), findsOneWidget);
      expect(fieldText(tester, 'Name'), 'Rahim');
      expect(fieldText(tester, 'Amount'), '1000');
      expect(find.byKey(const ValueKey('kind-locked')), findsNothing);
    });

    testWithDatabase('can change the name, the amount and the kind', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      await enterField(tester, 'Name', 'Rahim Uddin');
      await enterField(tester, 'Amount', '1500');
      await tapKey(tester, 'direction-borrowed');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      final debt = (await db.debtsDao.getAllDebts()).single;
      expect(debt.person, 'Rahim Uddin');
      expect(debt.amount, 150000);
      expect(debt.direction, DebtDirection.borrowed);
      expect(appBarTitle('Rahim Uddin'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳1,500.00');
    });

    testWithDatabase('moves the account balance with the new amount', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      // The loan is already counted in the balance, so it is not counted twice.
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('loan-account-switch')),
            )
            .value,
        isTrue,
      );
      await enterField(tester, 'Amount', '1500');
      await tester.pump();
      expect(textOf(tester, 'balance-after-$cash'), '-৳1,500.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(await balanceOf(db, cash), -150000);
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        hasLength(1),
      );
    });

    testWithDatabase('can stop using the account', (tester, db) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      await tapKey(tester, 'loan-account-switch');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(await balanceOf(db, cash), 0);
      expect((await db.debtsDao.getAllDebts()).single.accountId, isNull);
    });

    testWithDatabase('cannot change the kind once something is paid', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 10000);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      expect(find.byKey(const ValueKey('kind-locked')), findsOneWidget);
      await tapKey(tester, 'direction-borrowed');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(
        (await db.debtsDao.getAllDebts()).single.direction,
        DebtDirection.lent,
      );
    });

    testWithDatabase('cannot make the amount less than what is paid', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, amount: 100000, paid: 40000);
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      await enterField(tester, 'Amount', '300');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, 'form-error'),
        'The amount cannot be less than the ৳400.00 already paid.',
      );
      expect((await db.debtsDao.getAllDebts()).single.amount, 100000);
    });

    testWithDatabase('shows the pay back date and note already set', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, dueOn: DateTime(2026, 11, 5));
      await pumpAppWithDatabase(tester, db);
      await openEdit(tester, id);

      // "More details" is open because there is a pay back date.
      expect(find.text('5 Nov 2026'), findsOneWidget);
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
        find.textContaining('Lent to Rahim · not in your totals'),
        findsOneWidget,
      );
    });
  });
}
