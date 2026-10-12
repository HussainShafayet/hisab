import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;
  late int cash;
  late int bkash;
  late int food;
  late int transport;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = TransactionsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    transport = await insertTestCategory(db, name: 'Transport');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  TransactionInput expense({
    int amount = 25000,
    int? accountId,
    int? categoryId,
    DateTime? date,
    String note = '',
  }) => TransactionInput(
    type: TransactionType.expense,
    amount: amount,
    accountId: accountId ?? cash,
    categoryId: categoryId ?? food,
    date: date ?? _now,
    note: note,
  );

  TransactionInput income({int amount = 500000, DateTime? date}) =>
      TransactionInput(
        type: TransactionType.income,
        amount: amount,
        accountId: cash,
        categoryId: salary,
        date: date ?? _now,
      );

  TransactionInput transfer({
    int amount = 100000,
    int? from,
    int? to,
    int? categoryId,
  }) => TransactionInput(
    type: TransactionType.transfer,
    amount: amount,
    accountId: from ?? cash,
    toAccountId: to ?? bkash,
    categoryId: categoryId,
    date: _now,
  );

  Future<int> balanceOf(int accountId) async {
    final accounts = await AccountsRepository(db)
        .watchAccounts(includeArchived: true)
        .first;
    return accounts.singleWhere((a) => a.account.id == accountId).balance;
  }

  Future<List<TransactionRow>> allRows() =>
      db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

  group('adding', () {
    test('saves an expense with a trimmed note', () async {
      final id = await repo.addTransaction(
        expense(
          amount: 12345,
          note: '  Lunch  ',
          date: DateTime(2026, 10, 9, 13),
        ),
      );

      final item = (await repo.getTransaction(id))!;

      expect(item.type, TransactionType.expense);
      expect(item.amount, 12345);
      expect(item.accountName, 'Cash');
      expect(item.categoryId, food);
      expect(item.categoryName, 'Food');
      expect(item.note, 'Lunch');
      expect(item.date, DateTime(2026, 10, 9, 13));
      expect(item.toAccountId, isNull);
    });

    test('saves an income', () async {
      final id = await repo.addTransaction(income());

      final item = (await repo.getTransaction(id))!;

      expect(item.type, TransactionType.income);
      expect(item.categoryName, 'Salary');
      expect(await balanceOf(cash), 500000);
    });

    test('saves a transfer between two accounts', () async {
      final id = await repo.addTransaction(transfer(amount: 70000));

      final item = (await repo.getTransaction(id))!;

      expect(item.type, TransactionType.transfer);
      expect(item.accountName, 'Cash');
      expect(item.toAccountName, 'bKash');
      expect(item.categoryId, isNull);
      expect(await balanceOf(cash), -70000);
      expect(await balanceOf(bkash), 70000);
    });

    test('rejects an amount of zero or less', () async {
      expect(
        () => repo.addTransaction(expense(amount: 0)),
        throwsValidation('above zero'),
      );
      expect(
        () => repo.addTransaction(expense(amount: -5)),
        throwsValidation('above zero'),
      );
    });

    test('rejects a note that is too long', () async {
      expect(
        () => repo.addTransaction(expense(note: 'x' * 501)),
        throwsValidation('500'),
      );
    });

    test('rejects an unknown or archived account', () async {
      expect(
        () => repo.addTransaction(expense(accountId: 999)),
        throwsValidation('Account not found'),
      );

      await db.accountsDao.setArchived(cash, archived: true);
      expect(
        () => repo.addTransaction(expense()),
        throwsValidation('"Cash" is archived'),
      );
    });

    test(
      'rejects a missing, unknown, archived or wrong-type category',
      () async {
        expect(
          () => repo.addTransaction(
            TransactionInput(
              type: TransactionType.expense,
              amount: 100,
              accountId: cash,
              date: _now,
            ),
          ),
          throwsValidation('Choose a category'),
        );
        expect(
          () => repo.addTransaction(expense(categoryId: 999)),
          throwsValidation('Category not found'),
        );
        expect(
          () => repo.addTransaction(expense(categoryId: salary)),
          throwsValidation('not an expense'),
        );

        await db.categoriesDao.setArchived(food, archived: true);
        expect(
          () => repo.addTransaction(expense()),
          throwsValidation('"Food" is archived'),
        );
      },
    );

    test('rejects a second account on an income or expense', () async {
      expect(
        () => repo.addTransaction(
          TransactionInput(
            type: TransactionType.expense,
            amount: 100,
            accountId: cash,
            toAccountId: bkash,
            categoryId: food,
            date: _now,
          ),
        ),
        throwsValidation('Only a transfer'),
      );
    });

    test('rejects an invalid transfer', () async {
      expect(
        () => repo.addTransaction(
          TransactionInput(
            type: TransactionType.transfer,
            amount: 100,
            accountId: cash,
            date: _now,
          ),
        ),
        throwsValidation('goes to'),
      );
      expect(
        () => repo.addTransaction(transfer(from: cash, to: cash)),
        throwsValidation('two different'),
      );
      expect(
        () => repo.addTransaction(transfer(categoryId: food)),
        throwsValidation('no category'),
      );

      await db.accountsDao.setArchived(bkash, archived: true);
      expect(
        () => repo.addTransaction(transfer()),
        throwsValidation('"bKash" is archived'),
      );
      expect(await allRows(), isEmpty);
    });
  });

  group('transfer fee', () {
    test(
      'is saved as a separate expense on the account the money leaves',
      () async {
        await repo.addTransaction(transfer(amount: 100000), fee: 1500);

        final rows = await allRows();
        expect(rows, hasLength(2));
        final fee = rows.singleWhere((r) => r.type == TransactionType.expense);
        expect(fee.amount, 1500);
        expect(fee.accountId, cash);
        expect(fee.note, transferFeeNote);
        expect(fee.date, _now);
        final category = (await db.categoriesDao.getById(fee.categoryId!))!;
        expect(category.name, transferFeeCategoryName);
        expect(category.type, CategoryType.expense);

        // 1,000 transferred plus 15 fee leave Cash; bKash only gets the 1,000.
        expect(await balanceOf(cash), -101500);
        expect(await balanceOf(bkash), 100000);
      },
    );

    test('reuses its category', () async {
      await repo.addTransaction(transfer(), fee: 100);
      await repo.addTransaction(transfer(), fee: 200);

      final categories = await db.categoriesDao.getAll(
        type: CategoryType.expense,
      );
      expect(
        categories.where((c) => c.name == transferFeeCategoryName),
        hasLength(1),
      );
    });

    test('uses the default "Fees & charges" category when it exists', () async {
      final seeded = createTestDatabase(seedDefaults: true);
      addTearDown(seeded.close);
      final seededRepo = TransactionsRepository(seeded);
      final from = (await seeded.accountsDao.getAll())[0].id;
      final to = (await seeded.accountsDao.getAll())[1].id;
      final before = (await seeded.categoriesDao.getAll()).length;

      await seededRepo.addTransaction(
        TransactionInput(
          type: TransactionType.transfer,
          amount: 5000,
          accountId: from,
          toAccountId: to,
          date: _now,
        ),
        fee: 100,
      );

      expect((await seeded.categoriesDao.getAll()).length, before);
    });

    test('is not saved when the transfer itself is invalid', () async {
      expect(
        () => repo.addTransaction(transfer(from: cash, to: cash), fee: 500),
        throwsValidation('two different'),
      );
      expect(await allRows(), isEmpty);
      expect(
        (await db.categoriesDao.getAll()).where(
          (c) => c.name == transferFeeCategoryName,
        ),
        isEmpty,
      );
    });

    test('must be zero or more, and only on a transfer', () async {
      expect(
        () => repo.addTransaction(transfer(), fee: -1),
        throwsValidation('negative'),
      );
      expect(
        () => repo.addTransaction(expense(), fee: 100),
        throwsValidation('Only a transfer'),
      );
      expect(await allRows(), isEmpty);
    });

    test('a fee of zero saves only the transfer', () async {
      await repo.addTransaction(transfer());

      expect(await allRows(), hasLength(1));
    });
  });

  group('updating', () {
    test('replaces the amount, category, account, date and note', () async {
      final id = await repo.addTransaction(expense(note: 'Lunch'));
      final before = (await repo.getTransaction(id))!;

      await repo.updateTransaction(
        id,
        expense(
          amount: 99900,
          accountId: bkash,
          categoryId: transport,
          date: DateTime(2026, 10, 3, 8),
          note: ' Taxi ',
        ),
      );

      final after = (await repo.getTransaction(id))!;
      expect(after.amount, 99900);
      expect(after.accountName, 'bKash');
      expect(after.categoryName, 'Transport');
      expect(after.date, DateTime(2026, 10, 3, 8));
      expect(after.note, 'Taxi');
      expect(after.createdAt, before.createdAt);
    });

    test('changes an expense into a transfer and back', () async {
      final id = await repo.addTransaction(expense());

      await repo.updateTransaction(id, transfer());
      var item = (await repo.getTransaction(id))!;
      expect(item.type, TransactionType.transfer);
      expect(item.categoryId, isNull);
      expect(item.toAccountName, 'bKash');

      await repo.updateTransaction(id, expense());
      item = (await repo.getTransaction(id))!;
      expect(item.type, TransactionType.expense);
      expect(item.toAccountId, isNull);
      expect(item.categoryName, 'Food');
    });

    test('checks the same rules as adding', () async {
      final id = await repo.addTransaction(expense());

      expect(
        () => repo.updateTransaction(id, expense(amount: 0)),
        throwsValidation('above zero'),
      );
      expect(
        () => repo.updateTransaction(id, expense(categoryId: salary)),
        throwsValidation('not an expense'),
      );
      expect(
        () => repo.updateTransaction(id, transfer(from: cash, to: cash)),
        throwsValidation('two different'),
      );
    });

    test('allows the archived account and category it already uses', () async {
      final id = await repo.addTransaction(expense());
      await db.accountsDao.setArchived(cash, archived: true);
      await db.categoriesDao.setArchived(food, archived: true);

      await repo.updateTransaction(id, expense(amount: 777));

      expect((await repo.getTransaction(id))!.amount, 777);
    });

    test(
      'does not allow switching to an archived account or category',
      () async {
        final id = await repo.addTransaction(expense());
        await db.accountsDao.setArchived(bkash, archived: true);
        await db.categoriesDao.setArchived(transport, archived: true);

        expect(
          () => repo.updateTransaction(id, expense(accountId: bkash)),
          throwsValidation('"bKash" is archived'),
        );
        expect(
          () => repo.updateTransaction(id, expense(categoryId: transport)),
          throwsValidation('"Transport" is archived'),
        );
      },
    );

    test('reports a missing transaction', () async {
      expect(
        () => repo.updateTransaction(999, expense()),
        throwsValidation('not found'),
      );
    });
  });

  group('deleting and restoring', () {
    test('deleting returns what was deleted', () async {
      final id = await repo.addTransaction(expense(amount: 5000, note: 'Tea'));

      final deleted = (await repo.deleteTransaction(id))!;

      expect(deleted.id, id);
      expect(deleted.amount, 5000);
      expect(deleted.categoryName, 'Food');
      expect(await repo.getTransaction(id), isNull);
      expect(await allRows(), isEmpty);
    });

    test('deleting a missing transaction returns null', () async {
      expect(await repo.deleteTransaction(999), isNull);
    });

    test('restoring brings back the same row', () async {
      final id = await repo.addTransaction(transfer(amount: 40000));
      final before = (await repo.getTransaction(id))!;
      final deleted = (await repo.deleteTransaction(id))!;

      await repo.restoreTransaction(deleted);

      final after = (await repo.getTransaction(id))!;
      expect(after.id, before.id);
      expect(after.type, before.type);
      expect(after.amount, before.amount);
      expect(after.accountId, before.accountId);
      expect(after.toAccountId, before.toAccountId);
      expect(after.date, before.date);
      expect(after.note, before.note);
      expect(after.createdAt, before.createdAt);
      expect(await balanceOf(bkash), 40000);
    });

    test('restoring keeps a balance adjustment marked as one', () async {
      await AccountsRepository(db).adjustBalance(cash, targetBalance: 5000);
      final item =
          (await repo.watchBetween(DateTime(2000), DateTime(2100)).first)
              .single;
      expect(item.isAdjustment, isTrue);

      final deleted = (await repo.deleteTransaction(item.id))!;
      await repo.restoreTransaction(deleted);

      expect((await repo.getTransaction(item.id))!.isAdjustment, isTrue);
    });

    test('an ordinary transaction is not an adjustment', () async {
      final id = await repo.addTransaction(expense());

      expect((await repo.getTransaction(id))!.isAdjustment, isFalse);
    });

    test('restoring works after the account was archived', () async {
      final id = await repo.addTransaction(expense());
      final deleted = (await repo.deleteTransaction(id))!;
      await db.accountsDao.setArchived(cash, archived: true);

      await repo.restoreTransaction(deleted);

      expect(await repo.getTransaction(id), isNotNull);
    });
  });

  group('reading', () {
    test('lists a date range newest first with names', () async {
      final older = await repo.addTransaction(
        expense(date: DateTime(2026, 10, 2)),
      );
      final newer = await repo.addTransaction(
        income(date: DateTime(2026, 10, 9)),
      );
      await repo.addTransaction(expense(date: DateTime(2026, 11, 1)));

      final items = await repo
          .watchBetween(DateTime(2026, 10), DateTime(2026, 11))
          .first;

      expect(items.map((i) => i.id), [newer, older]);
      expect(items.first.categoryName, 'Salary');
      expect(items.last.accountName, 'Cash');
    });

    test('lists a range that spans months', () async {
      final september = await repo.addTransaction(
        expense(date: DateTime(2026, 9, 28, 20)),
      );
      final october = await repo.addTransaction(
        expense(date: DateTime(2026, 10, 10, 18)),
      );
      await repo.addTransaction(expense(date: DateTime(2026, 9, 24)));
      await repo.addTransaction(expense(date: DateTime(2026, 10, 11, 9)));

      final items = await repo
          .watchBetween(DateTime(2026, 9, 25), DateTime(2026, 10, 11))
          .first;

      expect(items.map((i) => i.id), [october, september]);
    });

    test('carries the parent of a sub-category', () async {
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: food,
      );
      await repo.addTransaction(expense(categoryId: groceries));

      final item =
          (await repo
                  .watchBetween(DateTime(2026, 10), DateTime(2026, 11))
                  .first)
              .single;

      expect(item.categoryId, groceries);
      expect(item.categoryParentId, food);
    });

    test('emits again when a transaction is added', () async {
      final counts = <int>[];
      final subscription = repo
          .watchBetween(DateTime(2026, 10), DateTime(2026, 11))
          .listen((items) => counts.add(items.length));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repo.addTransaction(expense());
      await pumpEventQueue();

      expect(counts.first, 0);
      expect(counts.last, 1);
    });
  });

  group('form options', () {
    test('offer active accounts, defaulting to the one used last', () async {
      await repo.addTransaction(expense(accountId: bkash));

      final options = await repo.loadAddOptions(now: _now);

      expect(options.accounts.map((a) => a.name), ['Cash', 'bKash']);
      expect(options.defaultAccountId, bkash);
    });

    test('default to the first account when nothing was saved yet', () async {
      expect((await repo.loadAddOptions(now: _now)).defaultAccountId, cash);
    });

    test('skip an archived account, also as the default', () async {
      await repo.addTransaction(expense(accountId: bkash));
      await db.accountsDao.setArchived(bkash, archived: true);

      final options = await repo.loadAddOptions(now: _now);

      expect(options.accounts.map((a) => a.name), ['Cash']);
      expect(options.defaultAccountId, cash);
    });

    test('have no default account without accounts', () async {
      final empty = createTestDatabase();
      addTearDown(empty.close);

      final options = await TransactionsRepository(empty)
          .loadAddOptions(now: _now);

      expect(options.accounts, isEmpty);
      expect(options.defaultAccountId, isNull);
    });

    test('list active categories by type, with the most used apart', () async {
      await repo.addTransaction(expense(categoryId: transport));
      await repo.addTransaction(expense(categoryId: transport));
      await repo.addTransaction(expense(categoryId: food));
      final rent = await insertTestCategory(db, name: 'Rent');
      final gone = await insertTestCategory(db, name: 'Gone');
      await db.categoriesDao.setArchived(gone, archived: true);

      final options = await repo.loadAddOptions(now: _now);

      // The list stays in tree order; usage only fills the frequent row.
      expect(options.expenseCategories.map((c) => c.name), [
        'Food',
        'Transport',
        'Rent',
      ]);
      expect(options.frequentExpenseIds, [transport, food]);
      expect(options.incomeCategories.map((c) => c.name), ['Salary']);
      expect(options.frequentIncomeIds, isEmpty);
      expect(options.expenseCategories.map((c) => c.id), isNot(contains(gone)));
      expect(rent, isNonZero);
    });

    test('only count uses from the last 90 days', () async {
      for (var i = 0; i < 3; i++) {
        await repo.addTransaction(
          expense(
            categoryId: transport,
            date: _now.subtract(const Duration(days: 120)),
          ),
        );
      }
      await repo.addTransaction(
        expense(categoryId: food, date: _now.subtract(const Duration(days: 5))),
      );

      final options = await repo.loadAddOptions(now: _now);

      expect(options.frequentExpenseIds, [food]);
      expect(options.expenseCategories.map((c) => c.name), [
        'Food',
        'Transport',
      ]);
    });

    test('show at most six frequent categories', () async {
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        final id = await insertTestCategory(db, name: 'Extra $i');
        ids.add(id);
        await repo.addTransaction(expense(categoryId: id));
      }

      final options = await repo.loadAddOptions(now: _now);

      expect(options.frequentExpenseIds, hasLength(maxFrequentCategories));
    });

    test('list every sub-category right after what it is inside', () async {
      final groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: food,
      );
      await insertTestCategory(db, name: 'Rice', parentId: groceries);

      final options = await repo.loadAddOptions(now: _now);

      expect(options.expenseCategories.map((c) => c.name), [
        'Food',
        'Groceries',
        'Rice',
        'Transport',
      ]);
    });

    test(
      'include the archived account and category of a transaction being edited',
      () async {
        final id = await repo.addTransaction(expense());
        await db.accountsDao.setArchived(cash, archived: true);
        await db.categoriesDao.setArchived(food, archived: true);
        final editing = (await repo.getTransaction(id))!;

        final options = await repo.loadAddOptions(now: _now, editing: editing);

        expect(options.accounts.map((a) => a.name), contains('Cash'));
        expect(
          options.accounts.firstWhere((a) => a.name == 'Cash').isArchived,
          isTrue,
        );
        expect(options.expenseCategories.map((c) => c.name), contains('Food'));
        // Still not the default.
        expect(options.defaultAccountId, bkash);
      },
    );
  });
}
