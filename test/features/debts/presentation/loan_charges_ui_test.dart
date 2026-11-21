import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';
import 'debts_screen_test.dart'
    show
        balanceOf,
        enterField,
        longPressLoan,
        make,
        openDetail,
        openLoans,
        showGive,
        tapKey,
        textOf;

void main() {
  group('adding a charge to a loan I took', () {
    testWithDatabase(
      'the loan screen has the button, and a loan I gave does not',
      (tester, db) async {
        useTallScreen(tester);
        final taken = await make(db, direction: DebtDirection.borrowed);
        final given = await make(db, person: 'Karim');
        await pumpAppWithDatabase(tester, db);
        await openLoans(tester);

        await openDetail(tester, given);
        expect(find.byKey(const ValueKey('add-charge')), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await showGive(tester);
        await openDetail(tester, taken);
        expect(find.byKey(const ValueKey('add-charge')), findsOneWidget);
      },
    );

    testWithDatabase('a late fee is added to what is owed', (tester, db) async {
      useTallScreen(tester);
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      await enterField(tester, 'Amount', '50');
      await tapKey(tester, 'charge-save');

      expect(find.text('Charge added.'), findsOneWidget);
      expect(textOf(tester, 'remaining'), '৳1,050.00');
      expect(textOf(tester, 'paid-of-total'), 'Paid ৳0.00 of ৳1,050.00');
      expect(textOf(tester, 'charged-text'), 'Includes ৳50.00 of charges');
      final charges = await db.debtsDao.getCharges(id);
      expect(charges.single.amount, 5000);
      expect(charges.single.kind, DebtChargeKind.lateFee);
      // The amount borrowed is untouched.
      expect((await db.debtsDao.getDebt(id))!.amount, 100000);
    });

    testWithDatabase('the kind of charge can be chosen', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      await tapKey(tester, 'charge-kind-interest');
      await enterField(tester, 'Amount', '20');
      await tapKey(tester, 'charge-save');

      expect(
        (await db.debtsDao.getCharges(id)).single.kind,
        DebtChargeKind.interest,
      );
      // The charges are listed, with what they were for.
      expect(find.text('Charges'), findsOneWidget);
      expect(find.textContaining('Interest'), findsWidgets);
    });

    testWithDatabase('it is my expense too, and no balance changes', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      // On by default, and the account it is written on is shown.
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('charge-expense-switch')),
            )
            .value,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('charge-account')),
          matching: find.text('Cash'),
        ),
        findsOneWidget,
      );
      await enterField(tester, 'Amount', '50');
      await tapKey(tester, 'charge-save');

      expect(await balanceOf(db, cash), 0);
      final entries = await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      );
      expect(entries.where((t) => !t.isAdjustment), hasLength(1));
      expect((await db.debtsDao.getCharges(id)).single.expenseId, isNotNull);
    });

    testWithDatabase('the expense can be left out', (tester, db) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      await tapKey(tester, 'charge-expense-switch');
      expect(find.byKey(const ValueKey('charge-account')), findsNothing);
      await enterField(tester, 'Amount', '50');
      await tapKey(tester, 'charge-save');

      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
      expect(textOf(tester, 'remaining'), '৳1,050.00');
    });

    testWithDatabase('without any account there is no expense to ask about', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      expect(find.byKey(const ValueKey('charge-expense-switch')), findsNothing);
      await enterField(tester, 'Amount', '50');
      await tapKey(tester, 'charge-save');

      expect(textOf(tester, 'remaining'), '৳1,050.00');
    });

    testWithDatabase('an amount is needed', (tester, db) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      await tapKey(tester, 'charge-save');

      // Still asking, and nothing was saved.
      expect(find.byKey(const ValueKey('charge-save')), findsOneWidget);
      expect(await db.debtsDao.getCharges(id), isEmpty);
    });

    testWithDatabase('a loan that was all paid is opened again', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
        paid: 100000,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await tester.tap(find.text('Show paid ones'));
      await tester.pumpAndSettle();
      await openDetail(tester, id);

      await tapKey(tester, 'add-charge');
      await enterField(tester, 'Amount', '25');
      await tapKey(tester, 'charge-save');

      expect(textOf(tester, 'remaining'), '৳25.00');
      expect(find.byKey(const ValueKey('add-payment')), findsOneWidget);
    });

    testWithDatabase('the loan list menu has it for a loan I took only', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final taken = await make(db, direction: DebtDirection.borrowed);
      final given = await make(db, person: 'Karim');
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);

      await longPressLoan(tester, given);
      expect(find.byKey(const ValueKey('loan-action-charge')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await showGive(tester);
      await longPressLoan(tester, taken);
      expect(find.byKey(const ValueKey('loan-action-charge')), findsOneWidget);
      await tapKey(tester, 'loan-action-charge');
      expect(find.byKey(const ValueKey('charge-save')), findsOneWidget);
    });

    testWithDatabase('the list shows what is owed with the charge in it', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
      );
      await DebtsRepository(db).addCharge(
        id,
        amount: 5000,
        chargedOn: DateTime(2026, 10, 10),
        kind: DebtChargeKind.lateFee,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);

      expect(textOf(tester, 'debt-amount-$id'), '৳1,050.00');
    });
  });

  group('taking a charge back', () {
    testWithDatabase('a charge is deleted after asking, with its expense', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
      );
      final chargeId = await DebtsRepository(db).addCharge(
        id,
        amount: 5000,
        chargedOn: DateTime(2026, 10, 10),
        kind: DebtChargeKind.lateFee,
        accountId: cash,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);
      expect(textOf(tester, 'remaining'), '৳1,050.00');

      await tapKey(tester, 'delete-charge-$chargeId');
      expect(find.text('Delete this charge?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'remaining'), '৳1,000.00');
      expect(find.byKey(ValueKey('charge-$chargeId')), findsNothing);
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
    });

    testWithDatabase('asking and then saying no keeps the charge', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(db, direction: DebtDirection.borrowed);
      final chargeId = await DebtsRepository(db).addCharge(
        id,
        amount: 5000,
        chargedOn: DateTime(2026, 10, 10),
        kind: DebtChargeKind.lateFee,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'delete-charge-$chargeId');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('charge-$chargeId')), findsOneWidget);
      expect(await db.debtsDao.getCharges(id), hasLength(1));
    });

    testWithDatabase('a charge the payments already cover says so', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
      );
      final repo = DebtsRepository(db);
      final chargeId = await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: DateTime(2026, 10, 10),
        kind: DebtChargeKind.lateFee,
      );
      await repo.addPayment(id, amount: 105000, paidOn: DateTime(2026, 10, 11));
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await tester.tap(find.text('Show paid ones'));
      await tester.pumpAndSettle();
      await openDetail(tester, id);

      await tapKey(tester, 'delete-charge-$chargeId');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('The payments made already cover this charge.'),
        findsOneWidget,
      );
      expect(await db.debtsDao.getCharges(id), hasLength(1));
    });
  });

  group('a transfer charge when paying back', () {
    testWithDatabase('a payment can carry the charge the bank took', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
        accountId: cash,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      // The loan's own account is chosen, so the charge can be typed.
      expect(find.byKey(const ValueKey('payment-fee')), findsOneWidget);
      await enterField(tester, 'Amount', '400');
      await tester.enterText(find.byKey(const ValueKey('payment-fee')), '15');
      await tester.pump();
      // 1000 came in, 400 and the 15 charge go out.
      expect(textOf(tester, 'balance-after-$cash'), '৳585.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await balanceOf(db, cash), 100000 - 40000 - 1500);
      final fee = (await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      )).where((t) => !t.isAdjustment).single;
      expect(fee.amount, 1500);
      expect(textOf(tester, 'remaining'), '৳600.00');
    });

    testWithDatabase('the charge field is left out for a loan I gave', (
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

      expect(find.byKey(const ValueKey('payment-fee')), findsNothing);
    });

    testWithDatabase('without an account there is no charge to type', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await insertTestAccount(db, name: 'Cash');
      final id = await make(db, direction: DebtDirection.borrowed);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      expect(find.byKey(const ValueKey('payment-fee')), findsNothing);
      await tapKey(tester, 'payment-account-switch');
      expect(find.byKey(const ValueKey('payment-fee')), findsOneWidget);
      await tapKey(tester, 'payment-account-switch');
      expect(find.byKey(const ValueKey('payment-fee')), findsNothing);
    });

    testWithDatabase(
      'a charge typed and then the account switched off is not kept',
      (tester, db) async {
        useTallScreen(tester);
        final cash = await insertTestAccount(db, name: 'Cash');
        final id = await make(
          db,
          direction: DebtDirection.borrowed,
          amount: 100000,
          accountId: cash,
        );
        await pumpAppWithDatabase(tester, db);
        await openLoans(tester);
        await showGive(tester);
        await openDetail(tester, id);

        await tapKey(tester, 'add-payment');
        await tester.enterText(find.byKey(const ValueKey('payment-fee')), '15');
        await tester.pump();
        await tapKey(tester, 'payment-account-switch');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(
          (await db.transactionsDao.getBetween(
            DateTime(2000),
            DateTime(2100),
          )).where((t) => !t.isAdjustment),
          isEmpty,
        );
      },
    );

    testWithDatabase('a charge that is not an amount is refused', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(
        db,
        direction: DebtDirection.borrowed,
        amount: 100000,
        accountId: cash,
      );
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await showGive(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'add-payment');
      await tester.enterText(
        find.byKey(const ValueKey('payment-fee')),
        '1.2.3',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('payment-fee')), findsOneWidget);
      expect(await db.debtsDao.getAllPayments(), isEmpty);
    });

    testWithDatabase(
      'All paid can carry the charge too, and Undo takes it back',
      (tester, db) async {
        useTallScreen(tester);
        final cash = await insertTestAccount(db, name: 'Cash');
        final id = await make(
          db,
          direction: DebtDirection.borrowed,
          amount: 100000,
          accountId: cash,
        );
        await pumpAppWithDatabase(tester, db);
        await openLoans(tester);
        await showGive(tester);
        await openDetail(tester, id);

        await tapKey(tester, 'mark-paid');
        expect(find.byKey(const ValueKey('pay-all-fee')), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('pay-all-fee')), '10');
        await tester.pump();
        // 1000 came in; 1000 and the 10 charge go out.
        expect(textOf(tester, 'balance-after-$cash'), '-৳10.00');
        await tapKey(tester, 'pay-all-confirm');

        expect(find.text('All paid.'), findsOneWidget);
        expect(await balanceOf(db, cash), 100000 - 100000 - 1000);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(await balanceOf(db, cash), 100000);
        expect(
          (await db.transactionsDao.getBetween(
            DateTime(2000),
            DateTime(2100),
          )).where((t) => !t.isAdjustment),
          isEmpty,
        );
      },
    );

    testWithDatabase('All paid has no charge field for a loan I gave', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final cash = await insertTestAccount(db, name: 'Cash');
      final id = await make(db, amount: 100000, accountId: cash);
      await pumpAppWithDatabase(tester, db);
      await openLoans(tester);
      await openDetail(tester, id);

      await tapKey(tester, 'mark-paid');

      expect(find.byKey(const ValueKey('pay-all-fee')), findsNothing);
    });
  });
}
