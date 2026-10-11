import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late AccountsRepository repo;
  late int food;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = AccountsRepository(db);
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<void> addIncome(int accountId, int amount) =>
      db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.income,
          amount: amount,
          accountId: accountId,
          categoryId: Value(salary),
          date: DateTime(2026, 10, 1),
        ),
      );

  Future<void> addExpense(int accountId, int amount) =>
      db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: amount,
          accountId: accountId,
          categoryId: Value(food),
          date: DateTime(2026, 10, 2),
        ),
      );

  Future<void> addTransfer(int from, int to, int amount) =>
      db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.transfer,
          amount: amount,
          accountId: from,
          toAccountId: Value(to),
          date: DateTime(2026, 10, 3),
        ),
      );

  Future<int> balanceOf(int id) async {
    final accounts = await repo.watchAccounts(includeArchived: true).first;
    return accounts.singleWhere((a) => a.account.id == id).balance;
  }

  group('creating and editing', () {
    test('creates an account with trimmed name and defaults', () async {
      final id = await repo.createAccount(
        name: '  bKash  ',
        type: AccountType.mobileBanking,
      );

      final account = (await repo.getAccount(id))!;

      expect(account.name, 'bKash');
      expect(account.type, AccountType.mobileBanking);
      expect(account.openingBalance, 0);
      expect(account.includeInTotal, isTrue);
      expect(account.isArchived, isFalse);
    });

    test('keeps the opening balance and include-in-total choice', () async {
      final id = await repo.createAccount(
        name: 'Savings',
        type: AccountType.bank,
        openingBalance: 2500050,
        includeInTotal: false,
      );

      final account = (await repo.getAccount(id))!;

      expect(account.openingBalance, 2500050);
      expect(account.includeInTotal, isFalse);
    });

    test('rejects a blank or too long name', () async {
      expect(
        () => repo.createAccount(name: '   ', type: AccountType.cash),
        throwsValidation('required'),
      );
      expect(
        () => repo.createAccount(name: 'x' * 61, type: AccountType.cash),
        throwsValidation('60'),
      );
    });

    test('rejects a duplicate name, ignoring case', () async {
      await repo.createAccount(name: 'Cash', type: AccountType.cash);

      expect(
        () => repo.createAccount(name: ' cash ', type: AccountType.cash),
        throwsValidation('already exists'),
      );
    });

    test('points to restoring when the duplicate is archived', () async {
      final id = await repo.createAccount(name: 'Bank', type: AccountType.bank);
      await repo.archiveAccount(id);

      expect(
        () => repo.createAccount(name: 'Bank', type: AccountType.bank),
        throwsValidation('Restore it instead'),
      );
    });

    test('updates every field', () async {
      final id = await repo.createAccount(name: 'Cash', type: AccountType.cash);

      await repo.updateAccount(
        id,
        name: 'Wallet',
        type: AccountType.card,
        openingBalance: -10000,
        includeInTotal: false,
      );

      final account = (await repo.getAccount(id))!;
      expect(account.name, 'Wallet');
      expect(account.type, AccountType.card);
      expect(account.openingBalance, -10000);
      expect(account.includeInTotal, isFalse);
    });

    test('lets an account keep or re-case its own name', () async {
      final id = await repo.createAccount(name: 'Cash', type: AccountType.cash);

      await repo.updateAccount(
        id,
        name: 'CASH',
        type: AccountType.cash,
        openingBalance: 0,
        includeInTotal: true,
      );

      expect((await repo.getAccount(id))!.name, 'CASH');
    });

    test('rejects renaming to another account\'s name', () async {
      await repo.createAccount(name: 'Cash', type: AccountType.cash);
      final bank = await repo.createAccount(
        name: 'Bank',
        type: AccountType.bank,
      );

      expect(
        () => repo.updateAccount(
          bank,
          name: 'cash',
          type: AccountType.bank,
          openingBalance: 0,
          includeInTotal: true,
        ),
        throwsValidation('already exists'),
      );
    });

    test('reports a missing account', () async {
      expect(await repo.getAccount(999), isNull);
      expect(() => repo.archiveAccount(999), throwsValidation('not found'));
      expect(() => repo.restoreAccount(999), throwsValidation('not found'));
      expect(
        () => repo.updateAccount(
          999,
          name: 'x',
          type: AccountType.cash,
          openingBalance: 0,
          includeInTotal: true,
        ),
        throwsValidation('not found'),
      );
    });
  });

  group('balances', () {
    test('start at the opening balance', () async {
      final id = await repo.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: 100000,
      );

      expect(await balanceOf(id), 100000);
    });

    test('follow income, expense and transfers in both directions', () async {
      final cash = await repo.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: 100000,
      );
      final bkash = await repo.createAccount(
        name: 'bKash',
        type: AccountType.mobileBanking,
      );

      await addIncome(cash, 500000);
      await addExpense(cash, 120000);
      await addTransfer(cash, bkash, 200000);
      await addExpense(bkash, 30000);

      // 1,000 + 5,000 - 1,200 - 2,000
      expect(await balanceOf(cash), 100000 + 500000 - 120000 - 200000);
      // 2,000 - 300
      expect(await balanceOf(bkash), 200000 - 30000);
    });

    test(
      'a transfer moves money without changing the sum of accounts',
      () async {
        final cash = await repo.createAccount(
          name: 'Cash',
          type: AccountType.cash,
          openingBalance: 100000,
        );
        final bank = await repo.createAccount(
          name: 'Bank',
          type: AccountType.bank,
          openingBalance: 50000,
        );
        await addTransfer(cash, bank, 70000);

        final accounts = await repo.watchAccounts().first;

        expect(calculateTotalBalance(accounts), 150000);
      },
    );

    test('can be negative', () async {
      final id = await repo.createAccount(name: 'Card', type: AccountType.card);
      await addExpense(id, 25000);

      expect(await balanceOf(id), -25000);
    });

    test('emit again when a transaction is added', () async {
      final id = await repo.createAccount(name: 'Cash', type: AccountType.cash);
      final balances = <int>[];
      final subscription = repo.watchAccounts().listen(
        (accounts) => balances.add(accounts.single.balance),
      );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await addIncome(id, 4200);
      await pumpEventQueue();

      expect(balances.first, 0);
      expect(balances.last, 4200);
    });

    test('are listed oldest first, archived ones only on request', () async {
      final cash = await repo.createAccount(
        name: 'Cash',
        type: AccountType.cash,
      );
      final bank = await repo.createAccount(
        name: 'Bank',
        type: AccountType.bank,
      );
      await repo.archiveAccount(bank);

      final active = await repo.watchAccounts().first;
      final all = await repo.watchAccounts(includeArchived: true).first;

      expect(active.map((a) => a.account.id), [cash]);
      expect(all.map((a) => a.account.id), [cash, bank]);
      expect(all.last.account.isArchived, isTrue);
    });
  });

  group('archiving', () {
    test('keeps the account and its transactions', () async {
      final id = await repo.createAccount(name: 'Cash', type: AccountType.cash);
      await addIncome(id, 10000);

      await repo.archiveAccount(id);

      expect((await repo.getAccount(id))!.isArchived, isTrue);
      expect(await balanceOf(id), 10000);
      expect(
        await db.transactionsDao.getBetween(DateTime(2026), DateTime(2027)),
        hasLength(1),
      );
    });

    test('can be undone', () async {
      final id = await repo.createAccount(name: 'Cash', type: AccountType.cash);
      await repo.archiveAccount(id);
      await repo.restoreAccount(id);

      expect((await repo.getAccount(id))!.isArchived, isFalse);
      expect(await repo.watchAccounts().first, hasLength(1));
    });
  });

  group('adjusting the balance', () {
    late int cash;

    setUp(() async {
      cash = await repo.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: 100000,
      );
    });

    test('records income when the real balance is higher', () async {
      final adjustment = await repo.adjustBalance(cash, targetBalance: 130050);

      expect(adjustment!.type, TransactionType.income);
      expect(adjustment.amount, 30050);
      expect(await balanceOf(cash), 130050);

      final transaction = (await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      )).single;
      expect(transaction.type, TransactionType.income);
      expect(transaction.accountId, cash);
      expect(transaction.note, balanceAdjustmentNote);
      expect(transaction.isAdjustment, isTrue);
      final category = (await db.categoriesDao.getById(
        transaction.categoryId!,
      ))!;
      expect(category.name, balanceAdjustmentCategoryName);
      expect(category.type, CategoryType.income);
    });

    test('records expense when the real balance is lower', () async {
      final adjustment = await repo.adjustBalance(cash, targetBalance: 40000);

      expect(adjustment!.type, TransactionType.expense);
      expect(adjustment.amount, 60000);
      expect(await balanceOf(cash), 40000);

      final transaction = (await db.transactionsDao.getBetween(
        DateTime(2000),
        DateTime(2100),
      )).single;
      final category = (await db.categoriesDao.getById(
        transaction.categoryId!,
      ))!;
      expect(category.type, CategoryType.expense);
    });

    test('can bring the balance below zero', () async {
      await repo.adjustBalance(cash, targetBalance: -2500);

      expect(await balanceOf(cash), -2500);
    });

    test('does nothing when the balance already matches', () async {
      final adjustment = await repo.adjustBalance(cash, targetBalance: 100000);

      expect(adjustment, isNull);
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
    });

    test('accounts for earlier transactions', () async {
      await addExpense(cash, 20000);

      await repo.adjustBalance(cash, targetBalance: 100000);

      expect(await balanceOf(cash), 100000);
    });

    test('reuses its category instead of creating one each time', () async {
      await repo.adjustBalance(cash, targetBalance: 110000);
      await repo.adjustBalance(cash, targetBalance: 120000);
      await repo.adjustBalance(cash, targetBalance: 50000);
      await repo.adjustBalance(cash, targetBalance: 40000);

      final categories = await db.categoriesDao.getAll(includeArchived: true);
      final adjustmentCategories = categories.where(
        (c) => c.name == balanceAdjustmentCategoryName,
      );
      expect(adjustmentCategories.map((c) => c.type), [
        CategoryType.income,
        CategoryType.expense,
      ]);
    });

    test('still works when its category was archived', () async {
      await repo.adjustBalance(cash, targetBalance: 110000);
      final category = (await db.categoriesDao.getAll(
        type: CategoryType.income,
      )).singleWhere((c) => c.name == balanceAdjustmentCategoryName);
      await db.categoriesDao.setArchived(category.id, archived: true);

      await repo.adjustBalance(cash, targetBalance: 120000);

      expect(await balanceOf(cash), 120000);
    });

    test('works for an archived account', () async {
      await repo.archiveAccount(cash);

      await repo.adjustBalance(cash, targetBalance: 1);

      expect(await balanceOf(cash), 1);
    });

    test('reports a missing account', () async {
      expect(
        () => repo.adjustBalance(999, targetBalance: 0),
        throwsValidation('not found'),
      );
    });
  });
}
