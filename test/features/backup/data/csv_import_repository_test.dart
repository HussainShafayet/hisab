import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

const header = 'Date,Amount,Type,Category,Account,To account,Note';

void main() {
  late AppDatabase db;
  late CsvImportRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = CsvImportRepository(db);
  });
  tearDown(() => db.close());

  Future<ImportPlan> planOf(
    String body, {
    TypeSource typeSource = TypeSource.column,
    int? defaultAccountId,
  }) async {
    final table = parseCsvTable('$header\n$body');
    return buildImportPlan(
      table: table,
      mapping: ImportMapping(
        columns: guessColumns(table.headers),
        dateFormat: SheetDateFormat.dayMonthYear,
        typeSource: typeSource,
        defaultAccountId: defaultAccountId,
      ),
      context: await repo.loadContext(),
    );
  }

  Future<ImportResult> importBody(String body) async =>
      repo.apply(await planOf(body));

  group('reading what the app holds', () {
    test('lists accounts and categories, archived ones too', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      await db.accountsDao.setArchived(cash, archived: true);
      final food = await insertTestCategory(db, name: 'Food');
      await insertTestCategory(db, name: 'Groceries', parentId: food);

      final context = await repo.loadContext();

      expect(context.accounts.map((a) => a.name), ['Cash']);
      expect(context.categories.map((c) => c.name), ['Food', 'Groceries']);
      expect(context.categories.last.parentId, food);
    });

    test('counts existing transactions by their duplicate key', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      final food = await insertTestCategory(db, name: 'Food');
      for (final hour in [9, 18]) {
        await db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 6000,
            accountId: cash,
            categoryId: Value(food),
            date: DateTime(2026, 10, 11, hour),
            note: const Value('Rickshaw'),
          ),
        );
      }

      final context = await repo.loadContext();

      final key = duplicateKey(
        date: DateTime(2026, 10, 11),
        type: TransactionType.expense,
        amount: 6000,
        accountId: cash,
        note: 'rickshaw',
      );
      expect(context.existingKeyCounts[key], 2);
    });
  });

  group('importing', () {
    test('saves the rows as transactions', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      await insertTestCategory(db, name: 'Food');

      final result = await importBody(
        '11/10/2026,"1,250.50",expense,Food,Cash,,Lunch\n'
        '12/10/2026,500,expense,Food,Cash,,Tea\n',
      );

      expect(result.imported, 2);
      expect(result.duplicates, 0);
      expect(result.errors, 0);
      final rows = await db.transactionsDao.getAll();
      expect(rows.map((t) => t.amount), [125050, 50000]);
      expect(rows.first.accountId, cash);
      expect(rows.first.note, 'Lunch');
      expect(rows.first.date, DateTime(2026, 10, 11, 12));
      expect(rows.first.isAdjustment, isFalse);
    });

    test('creates accounts that are not there, with a guessed kind', () async {
      await insertTestCategory(db, name: 'Food');

      final result = await importBody(
        '11/10/2026,10,expense,Food,bKash,,\n'
        '11/10/2026,10,expense,Food,City Bank,,\n'
        '11/10/2026,10,expense,Food,Wallet,,\n'
        '12/10/2026,20,expense,Food,bkash,,\n',
      );

      expect(result.accountsCreated, 3);
      final accounts = await db.accountsDao.getAll();
      expect(accounts.map((a) => a.name), ['bKash', 'City Bank', 'Wallet']);
      expect(accounts.map((a) => a.type), [
        AccountType.mobileBanking,
        AccountType.bank,
        AccountType.cash,
      ]);
      expect(
        accounts.every((a) => a.openingBalance == 0 && a.includeInTotal),
        isTrue,
      );
      // Both bKash rows went to the one account.
      final bkash = accounts.first.id;
      expect(
        (await db.transactionsDao.getAll()).where((t) => t.accountId == bkash),
        hasLength(2),
      );
    });

    test('creates categories and sub-categories that are not there', () async {
      await insertTestAccount(db, name: 'Cash');
      final food = await insertTestCategory(db, name: 'Food');

      final result = await importBody(
        '11/10/2026,10,expense,Pets,Cash,,\n'
        '11/10/2026,10,expense,Food > Restaurants,Cash,,\n'
        '11/10/2026,10,expense,Fun > Games,Cash,,\n'
        '11/10/2026,10,income,Gifts,Cash,,\n',
      );

      expect(
        result.categoriesCreated,
        5,
      ); // Pets, Restaurants, Fun, Games, Gifts
      final categories = await db.categoriesDao.getAll();
      CategoryRow named(String name) =>
          categories.firstWhere((c) => c.name == name);
      expect(named('Pets').parentId, isNull);
      expect(named('Restaurants').parentId, food);
      expect(named('Games').parentId, named('Fun').id);
      expect(named('Fun').parentId, isNull);
      expect(named('Gifts').type, CategoryType.income);
      expect(named('Pets').type, CategoryType.expense);
    });

    test('puts new categories last among their siblings', () async {
      await insertTestAccount(db, name: 'Cash');
      await insertTestCategory(db, name: 'Food');
      await insertTestCategory(db, name: 'Rent');

      await importBody(
        '11/10/2026,10,expense,Pets,Cash,,\n11/10/2026,10,expense,Games,Cash,,\n',
      );

      final categories = await db.categoriesDao.getAll();
      final orders = {for (final c in categories) c.name: c.sortOrder};
      // The two existing categories have sort order 0 (the helper does not
      // set one), so the new ones follow: 1, then 2.
      expect(orders['Pets'], 1);
      expect(orders['Games'], 2);
    });

    test('rows with no category go to Other, or Other income, which is created once', () async {
      await insertTestAccount(db, name: 'Cash');

      await importBody(
        '11/10/2026,10,expense,,Cash,,\n'
        '12/10/2026,20,expense,,Cash,,\n'
        '13/10/2026,30,income,,Cash,,\n',
      );

      final categories = await db.categoriesDao.getAll();
      expect(categories.map((c) => c.name), ['Other', 'Other income']);
      final transactions = await db.transactionsDao.getAll();
      expect(transactions.map((t) => t.categoryId).toSet(), {
        categories.first.id,
        categories.last.id,
      });
    });

    test('saves a transfer with both accounts and no category', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      final bkash = await insertTestAccount(db, name: 'bKash');

      final result = await importBody(
        '11/10/2026,1000,transfer,,Cash,bKash,Cash out\n',
      );

      expect(result.imported, 1);
      final transfer = (await db.transactionsDao.getAll()).single;
      expect(transfer.type, TransactionType.transfer);
      expect(transfer.accountId, cash);
      expect(transfer.toAccountId, bkash);
      expect(transfer.categoryId, isNull);
      expect(await db.categoriesDao.getAll(), isEmpty);
    });

    test('uses the default account for rows without one', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      await insertTestCategory(db, name: 'Food');
      final plan = await planOf(
        '11/10/2026,10,expense,Food,,,\n',
        defaultAccountId: cash,
      );

      await repo.apply(plan);

      expect((await db.transactionsDao.getAll()).single.accountId, cash);
    });

    test('uses an archived account instead of creating it again', () async {
      final old = await insertTestAccount(db, name: 'Old bank');
      await db.accountsDao.setArchived(old, archived: true);
      await insertTestCategory(db, name: 'Food');

      final result = await importBody(
        '11/10/2026,10,expense,Food,Old bank,,\n',
      );

      expect(result.accountsCreated, 0);
      expect((await db.transactionsDao.getAll()).single.accountId, old);
    });

    test(
      'a negative amount is an expense when the sign decides the type',
      () async {
        await insertTestAccount(db, name: 'Cash');
        await insertTestCategory(db, name: 'Food');
        final plan = await planOf(
          '11/10/2026,-250,,Food,Cash,,\n',
          typeSource: TypeSource.amountSign,
        );

        await repo.apply(plan);

        final t = (await db.transactionsDao.getAll()).single;
        expect(t.type, TransactionType.expense);
        expect(t.amount, 25000);
      },
    );

    test('skips what cannot be read and reports it', () async {
      await insertTestAccount(db, name: 'Cash');
      await insertTestCategory(db, name: 'Food');

      final result = await importBody(
        '11/10/2026,10,expense,Food,Cash,,\n'
        'not a date,10,expense,Food,Cash,,\n'
        '12/10/2026,oops,expense,Food,Cash,,\n',
      );

      expect(result.imported, 1);
      expect(result.errors, 2);
      expect(await db.transactionsDao.getAll(), hasLength(1));
    });

    test('an empty plan changes nothing', () async {
      final result = await importBody('');

      expect(result.imported, 0);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await db.accountsDao.getAll(), isEmpty);
    });
  });

  group('importing the same file twice', () {
    test(
      'the second time every row is a duplicate and nothing is added',
      () async {
        await insertTestAccount(db, name: 'Cash');
        const body =
            '11/10/2026,60,expense,Food,Cash,,Rickshaw\n'
            '11/10/2026,60,expense,Food,Cash,,Rickshaw\n'
            '12/10/2026,500,income,Salary,bKash,,\n';
        final first = await importBody(body);
        expect(first.imported, 3);
        final countAfterFirst = (await db.transactionsDao.getAll()).length;

        final plan = await planOf(body);
        final second = await repo.apply(plan);

        expect(plan.duplicateCount, 3);
        expect(second.imported, 0);
        expect(second.duplicates, 3);
        expect(await db.transactionsDao.getAll(), hasLength(countAfterFirst));
        // Nothing was created either.
        expect(second.accountsCreated, 0);
        expect(second.categoriesCreated, 0);
      },
    );

    test('a file with some new rows adds only those', () async {
      await insertTestAccount(db, name: 'Cash');
      await importBody('11/10/2026,60,expense,Food,Cash,,Rickshaw\n');

      final second = await importBody(
        '11/10/2026,60,expense,Food,Cash,,Rickshaw\n'
        '12/10/2026,80,expense,Food,Cash,,Tea\n',
      );

      expect(second.imported, 1);
      expect(second.duplicates, 1);
      expect(await db.transactionsDao.getAll(), hasLength(2));
    });
  });

  group('when something goes wrong', () {
    test(
      'nothing is saved: not the transactions, nor the accounts and categories',
      () async {
        // An account name longer than the database allows fails partway.
        final longName = 'A' * 100;
        final plan = await planOf(
          '11/10/2026,10,expense,Pets,Nagad,,\n'
          '12/10/2026,10,expense,Pets,$longName,,\n',
        );

        await expectLater(repo.apply(plan), throwsA(anything));

        expect(await db.accountsDao.getAll(includeArchived: true), isEmpty);
        expect(await db.categoriesDao.getAll(includeArchived: true), isEmpty);
        expect(await db.transactionsDao.getAll(), isEmpty);
      },
    );
  });
}
