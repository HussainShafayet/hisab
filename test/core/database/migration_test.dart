import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/metals/domain/metals.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A test database is made at the current version. This takes the columns that
/// were added after [version] back out, so the file looks as that version left
/// it and the upgrade can add them again.
Future<void> dropColumnsAfter(AppDatabase db, int version) async {
  if (version < 6) {
    await db.customStatement('ALTER TABLE accounts DROP COLUMN credit_limit');
    await db.customStatement('ALTER TABLE accounts DROP COLUMN bill_due_day');
  }
  if (version < 7) {
    await db.customStatement('ALTER TABLE accounts DROP COLUMN usd_limit');
    await db.customStatement('ALTER TABLE transactions DROP COLUMN usd_amount');
  }
  if (version < 9) {
    await db.customStatement('ALTER TABLE transactions DROP COLUMN tag_id');
    await db.customStatement('DROP TABLE tags');
  }
  if (version < 10) {
    await db.customStatement('DROP TABLE shopping_items');
    await db.customStatement('DROP TABLE item_prices');
  }
  if (version < 11) {
    await db.customStatement('DROP TABLE metal_holdings');
  }
  if (version < 12) {
    await db.customStatement('ALTER TABLE transactions DROP COLUMN feeling');
  }
  if (version < 13) {
    await db.customStatement('DROP TABLE investment_entries');
    await db.customStatement('DROP TABLE investments');
  }
}

void main() {
  test(
    'upgrading from version 1 adds is_adjustment and marks old corrections',
    () async {
      final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/test.sqlite');

      // Build a database as the first version of the app left it: no
      // is_adjustment column, user_version 1, with a correction in it.
      var db = AppDatabase.withExecutor(
        NativeDatabase(file),
        seedDefaults: false,
      );
      final account = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
      );
      final food = await db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(name: 'Food', type: CategoryType.expense),
      );
      final correction = await db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(
          name: balanceAdjustmentCategoryName,
          type: CategoryType.income,
        ),
      );
      Future<int> add(int category, int amount, TransactionType type) =>
          db.transactionsDao.insertTransaction(
            TransactionsCompanion.insert(
              type: type,
              amount: amount,
              accountId: account,
              categoryId: Value(category),
              date: DateTime(2026, 10, 5),
            ),
          );
      final adjustmentId = await add(correction, 20000, TransactionType.income);
      final normalId = await add(food, 5000, TransactionType.expense);
      await db.customStatement(
        'ALTER TABLE transactions DROP COLUMN is_adjustment',
      );
      await dropColumnsAfter(db, 1);
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      // Opening it with the current app runs the upgrade.
      db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
      addTearDown(db.close);

      final adjustment = (await db.transactionsDao.getById(adjustmentId))!;
      final normal = (await db.transactionsDao.getById(normalId))!;
      expect(adjustment.isAdjustment, isTrue);
      expect(normal.isAdjustment, isFalse);
      // Nothing else was touched.
      expect(adjustment.amount, 20000);
      expect(normal.amount, 5000);
      expect(adjustment.categoryId, correction);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      // Every upgrade step ran, up to the current version.
      expect(version.read<int>('user_version'), 13);
    },
  );

  test('upgrading from version 2 adds the settings table', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    // A database as version 2 left it: no app_settings table.
    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await db.customStatement('DROP TABLE app_settings');
    await dropColumnsAfter(db, 2);
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // The table exists and works, and what was there is untouched.
    await db.settingsDao.put('language', 'bangla');
    expect(await db.settingsDao.getAll(), {'language': 'bangla'});
    expect((await db.accountsDao.getById(account))!.name, 'Cash');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 3 adds the loan tables', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await db.customStatement('DROP TABLE debt_payments');
    await db.customStatement('DROP TABLE debts');
    await dropColumnsAfter(db, 3);
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // Both tables exist and work, and what was there is untouched.
    final debt = await db.debtsDao.insertDebt(
      DebtsCompanion.insert(
        person: 'Rahim',
        direction: DebtDirection.lent,
        amount: 1000,
        openedOn: DateTime(2026, 10, 5),
      ),
    );
    await db.debtsDao.insertPayment(
      DebtPaymentsCompanion.insert(
        debtId: debt,
        amount: 400,
        paidOn: DateTime(2026, 10, 6),
      ),
    );
    expect((await db.debtsDao.getWithPaid(debt))!.paid, 400);
    expect((await db.accountsDao.getById(account))!.name, 'Cash');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 5 adds the credit card columns', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await dropColumnsAfter(db, 5);
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // The account that was there has no limit and no bill day.
    final old = (await db.accountsDao.getById(account))!;
    expect(old.name, 'Cash');
    expect(old.creditLimit, isNull);
    expect(old.billDueDay, isNull);
    // And a credit card can use both.
    final card = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'Visa',
        type: AccountType.creditCard,
        creditLimit: const Value(5000000),
        billDueDay: const Value(15),
      ),
    );
    final saved = (await db.accountsDao.getById(card))!;
    expect(saved.creditLimit, 5000000);
    expect(saved.billDueDay, 15);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 6 adds the dollar columns', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final card = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'EBL', type: AccountType.creditCard),
    );
    final shopping = await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(name: 'Shopping', type: CategoryType.expense),
    );
    final before = await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: 1000,
        accountId: card,
        categoryId: Value(shopping),
        date: DateTime(2026, 10, 1),
      ),
    );
    await dropColumnsAfter(db, 6);
    await db.customStatement('PRAGMA user_version = 6');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // What was there has no dollars.
    expect((await db.accountsDao.getById(card))!.usdLimit, isNull);
    expect((await db.transactionsDao.getById(before))!.usdAmount, isNull);
    // And both can hold them now.
    await db.accountsDao.updateAccount(
      (await db.accountsDao.getById(card))!
          .copyWith(usdLimit: const Value(25000)),
    );
    final after = await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: 305000,
        accountId: card,
        categoryId: Value(shopping),
        date: DateTime(2026, 10, 2),
        usdAmount: const Value(2500),
      ),
    );
    expect((await db.accountsDao.getById(card))!.usdLimit, 25000);
    expect((await db.transactionsDao.getById(after))!.usdAmount, 2500);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 7 adds the savings goal tables', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    await db.customStatement('DROP TABLE goal_entries');
    await db.customStatement('DROP TABLE savings_goals');
    await dropColumnsAfter(db, 7);
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    final goal = await db.goalsDao.insertGoal(
      SavingsGoalsCompanion.insert(name: 'Laptop', target: 8000000),
    );
    await db.goalsDao.insertEntry(
      GoalEntriesCompanion.insert(
        goalId: goal,
        amount: 1500,
        date: DateTime(2026, 10, 1),
      ),
    );
    expect((await db.goalsDao.getWithSaved(goal))!.saved, 1500);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 8 adds tags', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final cash = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    final food = await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(name: 'Food', type: CategoryType.expense),
    );
    final before = await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: 1000,
        accountId: cash,
        categoryId: Value(food),
        date: DateTime(2026, 10, 1),
      ),
    );
    await dropColumnsAfter(db, 8);
    await db.customStatement('PRAGMA user_version = 8');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // What was there has no tag.
    expect((await db.transactionsDao.getById(before))!.tagId, isNull);
    // And a transaction can have one now.
    final trip = await db.tagsDao.insertTag(
      TagsCompanion.insert(name: 'Cox\'s Bazar'),
    );
    final after = await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.expense,
        amount: 2000,
        accountId: cash,
        categoryId: Value(food),
        date: DateTime(2026, 10, 2),
        tagId: Value(trip),
      ),
    );
    expect((await db.transactionsDao.getById(after))!.tagId, trip);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 9 adds the bazar list tables', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    await dropColumnsAfter(db, 9);
    await db.customStatement('PRAGMA user_version = 9');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    final id = await db.bazarDao.insertItem(
      ShoppingItemsCompanion.insert(name: 'Rice'),
    );
    await db.bazarDao.rememberPrice(
      key: 'rice',
      name: 'Rice',
      price: 12000,
      at: DateTime(2026, 10, 1),
    );
    expect((await db.bazarDao.getItem(id))!.quantity, 1);
    expect((await db.bazarDao.priceFor('rice'))!.price, 12000);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test(
    'a new database starts at the current version with the column',
    () async {
      final db = AppDatabase.withExecutor(
        NativeDatabase.memory(),
        seedDefaults: false,
      );
      addTearDown(db.close);

      final columns = await db
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      expect(
        columns.map((c) => c.read<String>('name')),
        contains('is_adjustment'),
      );
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((t) => t.read<String>('name')),
        contains('app_settings'),
      );
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 13);
      expect(
        tables.map((t) => t.read<String>('name')),
        containsAll(['debts', 'debt_payments', 'recurring_rules']),
      );
    },
  );

  test('upgrading from version 10 adds the gold and silver table', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    await dropColumnsAfter(db, 10);
    await db.customStatement('PRAGMA user_version = 10');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    final id = await db.metalsDao.insertHolding(
      MetalHoldingsCompanion.insert(
        metal: Metal.gold,
        name: 'Necklace',
        milligrams: 23328,
        purity: 917,
      ),
    );
    expect((await db.metalsDao.getById(id))!.name, 'Necklace');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });

  test('upgrading from version 12 adds the investment tables', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    await dropColumnsAfter(db, 12);
    await db.customStatement('PRAGMA user_version = 12');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    final id = await db.investmentsDao.insertInvestment(
      InvestmentsCompanion.insert(
        name: 'Poultry farm',
        startedOn: DateTime(2026, 10, 1),
      ),
    );
    await db.investmentsDao.insertEntry(
      InvestmentEntriesCompanion.insert(
        investmentId: id,
        kind: InvestmentEntryKind.putIn,
        amount: 500000,
        date: DateTime(2026, 10, 1),
      ),
    );
    final item = (await db.investmentsDao.getWithSums(id))!;
    expect(item.putIn, 500000);
    // The index came with the table.
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_investment_entries_investment_id'",
        )
        .get();
    expect(indexes, hasLength(1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 13);
  });
}
