import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final _opened = DateTime(2026, 10, 1, 10);
final _paid = DateTime(2026, 10, 20, 9);

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

  Future<List<TransactionRow>> expenses() async {
    final all = await db.transactionsDao.getBetween(
      DateTime(2026, 10),
      DateTime(2026, 11),
    );
    return [
      for (final t in all)
        if (!t.isAdjustment) t,
    ];
  }

  group('a transfer charge paid with a payment', () {
    test('is an expense on the account, on top of the payment', () async {
      final id = await borrowed(account: cash);
      expect(await balance(cash), 100000);

      await repo.addPayment(
        id,
        amount: 40000,
        paidOn: _paid,
        accountId: cash,
        fee: 1500,
      );

      // 400 paid and 15 taken for sending it.
      expect(await balance(cash), 100000 - 40000 - 1500);
      final fee = (await expenses()).single;
      expect(fee.type, TransactionType.expense);
      expect(fee.amount, 1500);
      expect(fee.accountId, cash);
      expect(fee.note, 'Transfer charge paying Rahim');
      final category = await db.categoriesDao.getById(fee.categoryId!);
      expect(category!.name, 'Bank charge');
      final totals = await ReportsRepository(db)
          .totals((start: DateTime(2026, 10), end: DateTime(2026, 11)));
      expect(totals.expense, 1500);
    });

    test('does not count against the loan', () async {
      final id = await borrowed(account: cash);

      await repo.addPayment(
        id,
        amount: 40000,
        paidOn: _paid,
        accountId: cash,
        fee: 1500,
      );

      final item = (await repo.getDebt(id))!;
      expect(item.paid, 40000);
      expect(item.remaining, 60000);
    });

    test('goes in the bKash or Nagad charge category of that wallet', () async {
      final bkash = await insertTestAccount(db, name: 'bKash Personal');
      final nagad = await insertTestAccount(db, name: 'Nagad');
      final id = await borrowed();

      await repo.addPayment(
        id,
        amount: 1000,
        paidOn: _paid,
        accountId: bkash,
        fee: 100,
      );
      await repo.addPayment(
        id,
        amount: 1000,
        paidOn: _paid,
        accountId: nagad,
        fee: 100,
      );

      final names = [
        for (final t in await expenses())
          (await db.categoriesDao.getById(t.categoryId!))!.name,
      ];
      expect(names, unorderedEquals(['bKash charge', 'Nagad charge']));
    });

    test('is taken back with the payment', () async {
      final id = await borrowed(account: cash);
      final paymentId = await repo.addPayment(
        id,
        amount: 40000,
        paidOn: _paid,
        accountId: cash,
        fee: 1500,
      );

      await repo.deletePayment(paymentId);

      expect(await balance(cash), 100000);
      expect(await expenses(), isEmpty);
    });

    test('goes when the loan is deleted', () async {
      final id = await borrowed(account: cash);
      await repo.addPayment(
        id,
        amount: 40000,
        paidOn: _paid,
        accountId: cash,
        fee: 1500,
      );

      await repo.deleteDebt(id);

      expect(await expenses(), isEmpty);
      expect(await balance(cash), 0);
    });

    test('is nothing when it is zero', () async {
      final id = await borrowed(account: cash);

      await repo.addPayment(id, amount: 40000, paidOn: _paid, accountId: cash);

      expect(await expenses(), isEmpty);
      expect(await balance(cash), 60000);
    });

    test('needs an account', () async {
      final id = await borrowed();

      await expectLater(
        repo.addPayment(id, amount: 1000, paidOn: _paid, fee: 100),
        throwsValidation('Choose an account'),
      );
      expect((await repo.getDebt(id))!.paid, 0);
    });

    test('is only for a loan I took', () async {
      final lent = await repo.createDebt(
        person: 'Karim',
        direction: DebtDirection.lent,
        amount: 50000,
        openedOn: _opened,
      );

      await expectLater(
        repo.addPayment(
          lent,
          amount: 1000,
          paidOn: _paid,
          accountId: cash,
          fee: 100,
        ),
        throwsValidation('only be added to money you took'),
      );
    });

    test('cannot be negative', () async {
      final id = await borrowed();

      await expectLater(
        repo.addPayment(
          id,
          amount: 1000,
          paidOn: _paid,
          accountId: cash,
          fee: -5,
        ),
        throwsValidation('above zero'),
      );
    });

    test('is not saved when the payment is refused', () async {
      final id = await borrowed(amount: 1000);

      await expectLater(
        repo.addPayment(
          id,
          amount: 5000,
          paidOn: _paid,
          accountId: cash,
          fee: 100,
        ),
        throwsValidation('more than what is left'),
      );
      expect(await expenses(), isEmpty);
    });
  });
}
