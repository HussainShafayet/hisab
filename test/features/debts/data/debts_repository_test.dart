import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final opened = DateTime(2026, 10, 5, 10);

void main() {
  late AppDatabase db;
  late DebtsRepository repo;
  late int cash;
  late int bkash;

  setUp(() async {
    db = createTestDatabase();
    repo = DebtsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
  });
  tearDown(() => db.close());

  Future<int> balanceOf(int accountId) async {
    final accounts = await AccountsRepository(db).watchAccounts().first;
    return accounts.firstWhere((a) => a.account.id == accountId).balance;
  }

  Future<int> lend(
    int amount, {
    String person = 'Rahim',
    int? accountId,
    DateTime? dueOn,
  }) => repo.createDebt(
    person: person,
    direction: DebtDirection.lent,
    amount: amount,
    openedOn: opened,
    accountId: accountId,
    dueOn: dueOn,
  );

  Future<int> borrow(int amount, {String person = 'Karim', int? accountId}) =>
      repo.createDebt(
        person: person,
        direction: DebtDirection.borrowed,
        amount: amount,
        openedOn: opened,
        accountId: accountId,
      );

  Future<List<TransactionRow>> transactions() =>
      db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

  group('making a loan', () {
    test('saves it with what was given', () async {
      final id = await repo.createDebt(
        person: '  Rahim  ',
        direction: DebtDirection.lent,
        amount: 50000,
        openedOn: opened,
        dueOn: DateTime(2026, 11, 1),
        note: '  for rent  ',
      );

      final item = (await repo.getDebt(id))!;

      expect(item.debt.person, 'Rahim');
      expect(item.debt.direction, DebtDirection.lent);
      expect(item.debt.amount, 50000);
      expect(item.debt.openedOn, opened);
      expect(item.debt.dueOn, DateTime(2026, 11, 1));
      expect(item.debt.note, 'for rent');
      expect(item.paid, 0);
      expect(item.remaining, 50000);
    });

    test(
      'with no account changes no balance and makes no transaction',
      () async {
        await lend(50000);

        expect(await balanceOf(cash), 0);
        expect(await transactions(), isEmpty);
      },
    );

    test('rejects a blank or long name', () async {
      expect(
        () => lend(100, person: '  '),
        throwsValidation('Name is required'),
      );
      expect(
        () => lend(100, person: 'x' * 61),
        throwsValidation('60 characters'),
      );
    });

    test('rejects an amount that is not above zero', () async {
      expect(() => lend(0), throwsValidation('above zero'));
      expect(() => lend(-5), throwsValidation('above zero'));
    });

    test('rejects a due day before the day it was given', () async {
      expect(
        () => lend(100, dueOn: DateTime(2026, 10, 4)),
        throwsValidation('due day'),
      );
      // The same day is fine.
      expect(lend(100, dueOn: DateTime(2026, 10, 5)), completes);
    });

    test('rejects a note that is too long', () async {
      expect(
        () => repo.createDebt(
          person: 'A',
          direction: DebtDirection.lent,
          amount: 1,
          openedOn: opened,
          note: 'x' * 501,
        ),
        throwsValidation('500 characters'),
      );
    });

    test('rejects an account that is archived or missing', () async {
      await db.accountsDao.setArchived(bkash, archived: true);

      expect(() => lend(100, accountId: bkash), throwsValidation('archived'));
      expect(() => lend(100, accountId: 9999), throwsValidation('not found'));
      expect(await repo.watchDebts().first, isEmpty);
    });
  });

  group('money lent from an account', () {
    test('takes the amount out of the account', () async {
      await lend(50000, accountId: cash);

      expect(await balanceOf(cash), -50000);
    });

    test('records a correction that is not an expense', () async {
      await lend(50000, accountId: cash);

      final row = (await transactions()).single;
      expect(row.type, TransactionType.expense);
      expect(row.amount, 50000);
      expect(row.accountId, cash);
      expect(row.isAdjustment, isTrue);
      expect(row.note, 'Lent to Rahim');
      final category = (await db.categoriesDao.getById(row.categoryId!))!;
      expect(category.name, loanCategoryName);
      expect(category.type, CategoryType.expense);
    });

    test('is not counted as spending in reports', () async {
      await lend(50000, accountId: cash);

      final totals = await db.reportsDao.incomeExpenseTotals(
        DateTime(2026, 10),
        DateTime(2026, 11),
      );
      expect(totals.expense, 0);
      expect(totals.income, 0);
    });

    test('is dated the day it was given', () async {
      await lend(50000, accountId: cash);

      expect((await transactions()).single.date, opened);
    });
  });

  group('money borrowed into an account', () {
    test('adds the amount to the account', () async {
      await borrow(30000, accountId: bkash);

      expect(await balanceOf(bkash), 30000);
      final row = (await transactions()).single;
      expect(row.type, TransactionType.income);
      expect(row.isAdjustment, isTrue);
      expect(row.note, 'Borrowed from Karim');
    });

    test('uses a separate Loans category for income', () async {
      await lend(100, accountId: cash);
      await borrow(100, accountId: cash);

      final categories = await db.categoriesDao.getAll(includeArchived: true);
      final loans = categories
          .where((c) => c.name == loanCategoryName)
          .toList();
      expect(loans.map((c) => c.type), unorderedEquals(CategoryType.values));
    });

    test('is not counted as income in reports', () async {
      await borrow(30000, accountId: bkash);

      final totals = await db.reportsDao.incomeExpenseTotals(
        DateTime(2026, 10),
        DateTime(2026, 11),
      );
      expect(totals.income, 0);
    });
  });

  group('payments', () {
    test('reduce what is left and add up', () async {
      final id = await lend(100000);

      await repo.addPayment(id, amount: 25000, paidOn: DateTime(2026, 10, 6));
      await repo.addPayment(id, amount: 15000, paidOn: DateTime(2026, 10, 7));

      final item = (await repo.getDebt(id))!;
      expect(item.paid, 40000);
      expect(item.remaining, 60000);
      expect(item.isSettled, isFalse);
    });

    test('settle the loan when everything is paid', () async {
      final id = await lend(100000);

      await repo.addPayment(id, amount: 100000, paidOn: DateTime(2026, 10, 6));

      expect((await repo.getDebt(id))!.isSettled, isTrue);
    });

    test('cannot be more than what is left', () async {
      final id = await lend(100000);
      await repo.addPayment(id, amount: 90000, paidOn: DateTime(2026, 10, 6));

      expect(
        () => repo.addPayment(id, amount: 10001, paidOn: DateTime(2026, 10, 7)),
        throwsValidation('more than what is left'),
      );
      expect((await repo.getDebt(id))!.paid, 90000);
    });

    test('must be above zero', () async {
      final id = await lend(100000);

      expect(
        () => repo.addPayment(id, amount: 0, paidOn: DateTime(2026, 10, 6)),
        throwsValidation('above zero'),
      );
    });

    test('need a loan that exists', () async {
      expect(
        () => repo.addPayment(999, amount: 1, paidOn: DateTime(2026, 10, 6)),
        throwsValidation('not found'),
      );
    });

    test('are listed newest first', () async {
      final id = await lend(100000);
      await repo.addPayment(id, amount: 1000, paidOn: DateTime(2026, 10, 6));
      await repo.addPayment(id, amount: 2000, paidOn: DateTime(2026, 10, 9));
      await repo.addPayment(id, amount: 3000, paidOn: DateTime(2026, 10, 7));

      final payments = await repo.watchPayments(id).first;

      expect(payments.map((p) => p.amount), [2000, 3000, 1000]);
    });

    test('from someone I lent to bring money into the account', () async {
      final id = await lend(100000, accountId: cash);

      await repo.addPayment(
        id,
        amount: 40000,
        paidOn: DateTime(2026, 10, 8),
        accountId: bkash,
      );

      // Cash gave 1,000; bKash got 400 back.
      expect(await balanceOf(cash), -100000);
      expect(await balanceOf(bkash), 40000);
      final received = (await transactions()).firstWhere(
        (t) => t.accountId == bkash,
      );
      expect(received.type, TransactionType.income);
      expect(received.isAdjustment, isTrue);
      expect(received.note, 'Received from Rahim');
    });

    test('to someone I borrowed from take money out of the account', () async {
      final id = await borrow(100000, accountId: cash);

      await repo.addPayment(
        id,
        amount: 30000,
        paidOn: DateTime(2026, 10, 8),
        accountId: cash,
      );

      expect(await balanceOf(cash), 70000);
      final paid = (await transactions()).firstWhere(
        (t) => t.type == TransactionType.expense,
      );
      expect(paid.note, 'Paid to Karim');
    });

    test('with no account change no balance', () async {
      final id = await lend(100000, accountId: cash);

      await repo.addPayment(id, amount: 40000, paidOn: DateTime(2026, 10, 8));

      expect(await balanceOf(cash), -100000);
      expect(await transactions(), hasLength(1));
    });

    test('reject an archived account', () async {
      final id = await lend(100000);
      await db.accountsDao.setArchived(bkash, archived: true);

      expect(
        () => repo.addPayment(
          id,
          amount: 100,
          paidOn: DateTime(2026, 10, 8),
          accountId: bkash,
        ),
        throwsValidation('archived'),
      );
    });

    test('can be taken back, with the balance change', () async {
      final id = await lend(100000, accountId: cash);
      final paymentId = await repo.addPayment(
        id,
        amount: 40000,
        paidOn: DateTime(2026, 10, 8),
        accountId: cash,
      );
      expect(await balanceOf(cash), -60000);

      await repo.deletePayment(paymentId);

      expect(await balanceOf(cash), -100000);
      expect((await repo.getDebt(id))!.paid, 0);
      expect(await transactions(), hasLength(1));
    });

    test('taking back one that is not there says so', () async {
      expect(() => repo.deletePayment(999), throwsValidation('not found'));
    });
  });

  group('changing a loan', () {
    test('changes the name, due day and note, not the money', () async {
      final id = await lend(50000, accountId: cash);

      await repo.updateDebt(
        id,
        person: '  Rahim Uddin ',
        dueOn: DateTime(2026, 12, 1),
        note: 'new note',
      );

      final item = (await repo.getDebt(id))!;
      expect(item.debt.person, 'Rahim Uddin');
      expect(item.debt.dueOn, DateTime(2026, 12, 1));
      expect(item.debt.note, 'new note');
      expect(item.debt.amount, 50000);
      expect(item.debt.direction, DebtDirection.lent);
      expect(item.debt.accountId, cash);
      expect(await balanceOf(cash), -50000);
    });

    test('can lose its due day', () async {
      final id = await lend(50000, dueOn: DateTime(2026, 11, 1));

      await repo.updateDebt(id, person: 'Rahim', dueOn: null, note: '');

      expect((await repo.getDebt(id))!.debt.dueOn, isNull);
    });

    test('is checked like a new one', () async {
      final id = await lend(50000);

      expect(
        () => repo.updateDebt(id, person: '', dueOn: null, note: ''),
        throwsValidation('Name is required'),
      );
      expect(
        () => repo.updateDebt(
          id,
          person: 'Rahim',
          dueOn: DateTime(2026, 10, 1),
          note: '',
        ),
        throwsValidation('due day'),
      );
      expect(
        () => repo.updateDebt(999, person: 'A', dueOn: null, note: ''),
        throwsValidation('not found'),
      );
    });
  });

  group('deleting a loan', () {
    test('removes it, its payments and every balance change', () async {
      final id = await lend(100000, accountId: cash);
      await repo.addPayment(
        id,
        amount: 30000,
        paidOn: DateTime(2026, 10, 8),
        accountId: cash,
      );
      await repo.addPayment(id, amount: 10000, paidOn: DateTime(2026, 10, 9));
      expect(await balanceOf(cash), -70000);

      await repo.deleteDebt(id);

      expect(await repo.getDebt(id), isNull);
      expect(await db.debtsDao.getAllPayments(), isEmpty);
      expect(await transactions(), isEmpty);
      expect(await balanceOf(cash), 0);
    });

    test('leaves other loans alone', () async {
      final first = await lend(100000, accountId: cash);
      final second = await lend(50000, person: 'Salma', accountId: cash);

      await repo.deleteDebt(first);

      expect(await repo.getDebt(second), isNotNull);
      expect(await balanceOf(cash), -50000);
      expect(await transactions(), hasLength(1));
    });

    test('says so when it is not there', () async {
      expect(() => repo.deleteDebt(999), throwsValidation('not found'));
    });

    test('still works when a transaction was deleted from the list', () async {
      final id = await lend(100000, accountId: cash);
      await db.transactionsDao.deleteTransaction(
        (await transactions()).single.id,
      );

      await repo.deleteDebt(id);

      expect(await repo.getDebt(id), isNull);
    });
  });

  group('reading', () {
    test('lists loans newest first with what was paid', () async {
      final first = await lend(100000);
      final second = await borrow(20000);
      await repo.addPayment(
        first,
        amount: 10000,
        paidOn: DateTime(2026, 10, 6),
      );

      final items = await repo.watchDebts().first;

      expect(items.map((i) => i.debt.id), [second, first]);
      expect(items.map((i) => i.paid), [0, 10000]);
    });

    test('emits again when a payment is added', () async {
      final id = await lend(100000);
      final seen = <int>[];
      final subscription = repo
          .watchDebt(id)
          .listen((i) => seen.add(i?.paid ?? -1));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repo.addPayment(id, amount: 5000, paidOn: DateTime(2026, 10, 6));
      await pumpEventQueue();

      expect(seen.first, 0);
      expect(seen.last, 5000);
    });

    test('a loan that is gone is null', () async {
      expect(await repo.watchDebt(999).first, isNull);
      expect(await repo.getDebt(999), isNull);
    });

    test('knows the people already used, most recent first', () async {
      await lend(1, person: 'Rahim');
      await borrow(1, person: 'Karim');
      await lend(1, person: 'rahim');
      await lend(1, person: 'Salma');

      expect(await repo.knownPeople(), ['Salma', 'rahim', 'Karim']);
    });
  });
}
