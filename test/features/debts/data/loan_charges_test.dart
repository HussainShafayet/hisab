import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final _opened = DateTime(2026, 10, 1, 10);
final _charged = DateTime(2026, 10, 20, 9);

void main() {
  late AppDatabase db;
  late DebtsRepository repo;
  late int cash;

  setUp(() async {
    db = createTestDatabase();
    repo = DebtsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
  });
  tearDown(() => db.close());

  Future<int> borrowed({int amount = 100000, int? account}) => repo.createDebt(
    person: 'Rahim',
    direction: DebtDirection.borrowed,
    amount: amount,
    openedOn: _opened,
    accountId: account,
  );

  Future<int> balance(int id) async {
    final accounts = await AccountsRepository(db).watchAccounts().first;
    return accounts.firstWhere((a) => a.account.id == id).balance;
  }

  group('a charge on a loan I took', () {
    test('adds to what is owed, not to the amount borrowed', () async {
      final id = await borrowed();

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      final item = (await repo.getDebt(id))!;
      expect(item.debt.amount, 100000);
      expect(item.charged, 5000);
      expect(item.total, 105000);
      expect(item.remaining, 105000);
    });

    test('is added to what is left after a payment', () async {
      final id = await borrowed();
      await repo.addPayment(id, amount: 40000, paidOn: _charged);

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.interest,
      );

      final item = (await repo.getDebt(id))!;
      expect(item.paid, 40000);
      expect(item.remaining, 65000);
      expect(item.progress, closeTo(40000 / 105000, 0.0001));
    });

    test('reopens a loan that was all paid', () async {
      final id = await borrowed(amount: 100000);
      await repo.addPayment(id, amount: 100000, paidOn: _charged);
      expect((await repo.getDebt(id))!.isSettled, isTrue);

      await repo.addCharge(
        id,
        amount: 2500,
        chargedOn: _charged,
        kind: DebtChargeKind.serviceCharge,
      );

      final item = (await repo.getDebt(id))!;
      expect(item.isSettled, isFalse);
      expect(item.remaining, 2500);
    });

    test('adds up several charges', () async {
      final id = await borrowed();
      await repo.addCharge(
        id,
        amount: 3000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );
      await repo.addCharge(
        id,
        amount: 2000,
        chargedOn: _charged,
        kind: DebtChargeKind.other,
      );

      expect((await repo.getDebt(id))!.charged, 5000);
      final list = await repo.watchCharges(id).first;
      expect(list.map((c) => c.kind), hasLength(2));
    });

    test('shows in the totals of what I owe', () async {
      final id = await borrowed();
      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      final totals = debtTotals(await repo.watchDebts().first, _charged);

      expect(totals.toPay, 105000);
    });

    test('is also my expense, with no change in any balance', () async {
      final id = await borrowed();

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
        accountId: cash,
      );

      // The balance is as it was: nothing was paid or received.
      expect(await balance(cash), 0);
      // And the expense is counted, in a fee category.
      final totals = await ReportsRepository(db)
          .totals((start: DateTime(2026, 10), end: DateTime(2026, 11)));
      expect(totals.expense, 5000);
      expect(totals.income, 0);
      final all = await db.transactionsDao.getBetween(
        DateTime(2026, 10),
        DateTime(2026, 11),
      );
      final expense = all.singleWhere((t) => !t.isAdjustment);
      expect(expense.type, TransactionType.expense);
      expect(expense.amount, 5000);
      expect(expense.note, 'Late fee on loan from Rahim');
      final category = await db.categoriesDao.getById(expense.categoryId!);
      expect(category!.name, 'Late fee');
      expect((await repo.watchCharges(id).first).single.isExpense, isTrue);
    });

    test('uses the note as the note of the expense', () async {
      final id = await borrowed();

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.interest,
        note: 'October interest',
        accountId: cash,
      );

      final all = await db.transactionsDao.getBetween(
        DateTime(2026, 10),
        DateTime(2026, 11),
      );
      expect(all.singleWhere((t) => !t.isAdjustment).note, 'October interest');
      final category = await db.categoriesDao.getById(
        all.singleWhere((t) => !t.isAdjustment).categoryId!,
      );
      expect(category!.name, 'Loan interest');
    });

    test('can leave my spending alone', () async {
      final id = await borrowed();

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      expect(
        await db.transactionsDao.getBetween(
          DateTime(2026, 10),
          DateTime(2026, 11),
        ),
        isEmpty,
      );
      expect((await repo.watchCharges(id).first).single.isExpense, isFalse);
    });

    test('is only for a loan I took', () async {
      final lent = await repo.createDebt(
        person: 'Karim',
        direction: DebtDirection.lent,
        amount: 50000,
        openedOn: _opened,
      );

      await expectLater(
        repo.addCharge(
          lent,
          amount: 1000,
          chargedOn: _charged,
          kind: DebtChargeKind.lateFee,
        ),
        throwsValidation('only be added to money you took'),
      );
    });

    test('needs an amount above zero', () async {
      final id = await borrowed();

      await expectLater(
        repo.addCharge(
          id,
          amount: 0,
          chargedOn: _charged,
          kind: DebtChargeKind.lateFee,
        ),
        throwsValidation('above zero'),
      );
    });

    test('needs a loan that exists', () async {
      await expectLater(
        repo.addCharge(
          999,
          amount: 100,
          chargedOn: _charged,
          kind: DebtChargeKind.lateFee,
        ),
        throwsValidation('Loan not found'),
      );
    });

    test('cannot be written on an archived account', () async {
      final id = await borrowed();
      await AccountsRepository(db).archiveAccount(cash);

      await expectLater(
        repo.addCharge(
          id,
          amount: 100,
          chargedOn: _charged,
          kind: DebtChargeKind.lateFee,
          accountId: cash,
        ),
        throwsValidation('archived'),
      );
      // Nothing was saved.
      expect((await repo.getDebt(id))!.charged, 0);
    });
  });

  group('taking a charge back', () {
    test('takes it off what is owed, with its expense', () async {
      final id = await borrowed();
      final chargeId = await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
        accountId: cash,
      );

      await repo.deleteCharge(chargeId);

      expect((await repo.getDebt(id))!.remaining, 100000);
      expect(
        await db.transactionsDao.getBetween(
          DateTime(2026, 10),
          DateTime(2026, 11),
        ),
        isEmpty,
      );
      expect(await repo.watchCharges(id).first, isEmpty);
    });

    test('is refused when the payments already cover it', () async {
      final id = await borrowed(amount: 100000);
      final chargeId = await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );
      await repo.addPayment(id, amount: 105000, paidOn: _charged);

      await expectLater(
        repo.deleteCharge(chargeId),
        throwsValidation('already cover this charge'),
      );
      expect((await repo.getDebt(id))!.charged, 5000);
    });

    test('says so for a charge that is not there', () async {
      await expectLater(
        repo.deleteCharge(999),
        throwsValidation('Charge not found'),
      );
    });
  });

  group('a loan with charges', () {
    test('is deleted with its charges and their expenses', () async {
      final id = await borrowed();
      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
        accountId: cash,
      );

      await repo.deleteDebt(id);

      expect(await db.debtsDao.getAllCharges(), isEmpty);
      expect(
        await db.transactionsDao.getBetween(
          DateTime(2026, 10),
          DateTime(2026, 11),
        ),
        isEmpty,
      );
    });

    test('keeps its balance change when only a charge is added', () async {
      final id = await borrowed(account: cash);
      expect(await balance(cash), 100000);

      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
        accountId: cash,
      );

      // Still the 1,000 that came in; the fee moved nothing.
      expect(await balance(cash), 100000);
    });

    test('keeps the amount when edited, and the charge on top', () async {
      final id = await borrowed(account: cash);
      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      await repo.updateDebt(
        id,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 120000,
        openedOn: _opened,
        dueOn: null,
        note: '',
        accountId: cash,
      );

      final item = (await repo.getDebt(id))!;
      expect(item.debt.amount, 120000);
      expect(item.total, 125000);
      // The balance follows the amount borrowed, not the charge.
      expect(await balance(cash), 120000);
    });

    test('cannot become a loan I gave', () async {
      final id = await borrowed();
      await repo.addCharge(
        id,
        amount: 5000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      await expectLater(
        repo.updateDebt(
          id,
          person: 'Rahim',
          direction: DebtDirection.lent,
          amount: 100000,
          openedOn: _opened,
          dueOn: null,
          note: '',
          accountId: null,
        ),
        throwsValidation('once a charge is added'),
      );
    });

    test('lets the amount go down to what the payments need', () async {
      final id = await borrowed(amount: 100000);
      await repo.addCharge(
        id,
        amount: 10000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );
      await repo.addPayment(id, amount: 105000, paidOn: _charged);

      // 95,000 + 10,000 of charges still covers the 105,000 paid.
      await repo.updateDebt(
        id,
        person: 'Rahim',
        direction: DebtDirection.borrowed,
        amount: 95000,
        openedOn: _opened,
        dueOn: null,
        note: '',
        accountId: null,
      );
      expect((await repo.getDebt(id))!.total, 105000);

      await expectLater(
        repo.updateDebt(
          id,
          person: 'Rahim',
          direction: DebtDirection.borrowed,
          amount: 90000,
          openedOn: _opened,
          dueOn: null,
          note: '',
          accountId: null,
        ),
        throwsValidation('cannot be less than'),
      );
    });

    test('is set off with what the person owes me, charges included', () async {
      final taken = await borrowed(amount: 100000);
      await repo.createDebt(
        person: 'Rahim',
        direction: DebtDirection.lent,
        amount: 60000,
        openedOn: _opened,
      );
      await repo.addCharge(
        taken,
        amount: 10000,
        chargedOn: _charged,
        kind: DebtChargeKind.lateFee,
      );

      await repo.setOff('Rahim', on: _charged);

      // 60,000 each way is set off; 50,000 of the 110,000 is left.
      expect((await repo.getDebt(taken))!.remaining, 50000);
    });
  });
}
