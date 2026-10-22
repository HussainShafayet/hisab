import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

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
    Map<String, int> categoryMap = const {},
  }) async {
    final table = parseCsvTable('Date,Amount,Type,Category,Account\n$body');
    return buildImportPlan(
      table: table,
      mapping: ImportMapping(
        columns: guessColumns(table.headers),
        dateFormat: SheetDateFormat.dayMonthYear,
        typeSource: TypeSource.column,
      ),
      context: await repo.loadContext(),
      categoryMap: categoryMap,
    );
  }

  Future<ImportResult> importBody(
    String body, {
    String file = 'sheet.csv',
  }) async => repo.apply(await planOf(body), fileName: file);

  Future<List<ImportBatchRow>> batches() => db.select(db.importBatches).get();

  Future<AccountRow> accountNamed(String name) async =>
      (await db.accountsDao.getAll(includeArchived: true))
          .firstWhere((a) => a.name == name);

  Future<CategoryRow> categoryNamed(String name) async =>
      (await db.categoriesDao.getAll(includeArchived: true))
          .firstWhere((c) => c.name == name);

  group('keeping an import', () {
    test('the batch holds what was made, and marks its transactions', () async {
      final result = await importBody(
        '11/10/2026,100,expense,Pets,Wallet\n12/10/2026,50,expense,Pets,Wallet',
      );

      final batch = (await batches()).single;
      expect(result.batchId, batch.id);
      expect(batch.fileName, 'sheet.csv');
      expect(batch.transactionCount, 2);
      expect(batch.createdAccountIds, '${(await accountNamed('Wallet')).id}');
      expect(batch.createdCategoryIds, '${(await categoryNamed('Pets')).id}');

      final transactions = await db.transactionsDao.getAll();
      expect(transactions.map((t) => t.importBatchId), [batch.id, batch.id]);
    });

    test('an import that adds nothing keeps no batch', () async {
      await insertTestAccount(db, name: 'Cash');

      final result = await importBody('11/10/2026,abc,expense,Food,Cash');

      expect(result.imported, 0);
      expect(result.batchId, isNull);
      expect(await batches(), isEmpty);
    });

    test('a category matched by hand is used and not made', () async {
      await insertTestAccount(db, name: 'Cash');
      final food = await insertTestCategory(db, name: 'Food');

      final plan = await planOf(
        '11/10/2026,100,expense,Foods,Cash',
        categoryMap: {
          categoryKey(CategoryType.expense, ['Foods']): food,
        },
      );
      final result = await repo.apply(plan, fileName: 'sheet.csv');

      expect(result.categoriesCreated, 0);
      expect((await db.transactionsDao.getAll()).single.categoryId, food);
      expect((await batches()).single.createdCategoryIds, isEmpty);
    });

    test('a category that is not there any more is made as before', () async {
      await insertTestAccount(db, name: 'Cash');

      final plan = await planOf(
        '11/10/2026,100,expense,Foods,Cash',
        categoryMap: {
          categoryKey(CategoryType.expense, ['Foods']): 9999,
        },
      );
      final result = await repo.apply(plan);

      expect(result.categoriesCreated, 1);
    });

    test('entries made by hand carry no batch', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      final food = await insertTestCategory(db, name: 'Food');
      final id = await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 100,
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 10, 11),
      );

      expect((await db.transactionsDao.getById(id))!.importBatchId, isNull);
    });
  });

  group('undoing an import', () {
    test('takes away its transactions and hides what it made', () async {
      final cash = await insertTestAccount(db, name: 'Cash');
      final food = await insertTestCategory(db, name: 'Food');
      final byHand = await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 700,
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 10, 1),
      );
      final result = await importBody(
        '11/10/2026,100,expense,Pets,Wallet\n12/10/2026,50,income,Gifts,Cash',
      );

      final undone = await repo.undo(result.batchId!);

      expect(undone.transactions, 2);
      expect(undone.categoriesHidden, 2);
      expect(undone.accountsHidden, 1);
      expect((await db.transactionsDao.getAll()).map((t) => t.id), [byHand]);
      expect((await categoryNamed('Pets')).isArchived, isTrue);
      expect((await categoryNamed('Gifts')).isArchived, isTrue);
      expect((await accountNamed('Wallet')).isArchived, isTrue);
      // An account that was there before is not touched.
      expect((await accountNamed('Cash')).isArchived, isFalse);
      expect(await batches(), isEmpty);
    });

    test('keeps what an entry made since still uses', () async {
      final result = await importBody('11/10/2026,100,expense,Pets,Wallet');
      final wallet = await accountNamed('Wallet');
      final pets = await categoryNamed('Pets');
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 300,
        accountId: wallet.id,
        categoryId: pets.id,
        date: DateTime(2026, 10, 20),
      );

      final undone = await repo.undo(result.batchId!);

      expect(undone.transactions, 1);
      expect(undone.categoriesHidden, 0);
      expect(undone.accountsHidden, 0);
      expect((await categoryNamed('Pets')).isArchived, isFalse);
      expect((await accountNamed('Wallet')).isArchived, isFalse);
    });

    test('hides a category made inside another, innermost first', () async {
      final result = await importBody('11/10/2026,100,expense,Pets > Dog,Cash');

      final undone = await repo.undo(result.batchId!);

      expect(undone.categoriesHidden, 2);
      expect((await categoryNamed('Dog')).isArchived, isTrue);
      expect((await categoryNamed('Pets')).isArchived, isTrue);
    });

    test('keeps the parent when another category is still inside it', () async {
      final result = await importBody('11/10/2026,100,expense,Pets > Dog,Cash');
      final pets = await categoryNamed('Pets');
      await insertTestCategory(db, name: 'Cat', parentId: pets.id);

      final undone = await repo.undo(result.batchId!);

      expect(undone.categoriesHidden, 1);
      expect((await categoryNamed('Dog')).isArchived, isTrue);
      expect((await categoryNamed('Pets')).isArchived, isFalse);
    });

    test('keeps a category that has a budget', () async {
      final result = await importBody('11/10/2026,100,expense,Pets,Cash');
      final pets = await categoryNamed('Pets');
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              month: '2026-10',
              categoryId: Value(pets.id),
              amount: 5000,
            ),
          );

      final undone = await repo.undo(result.batchId!);

      expect(undone.categoriesHidden, 0);
    });

    test('an import that was already undone cannot be undone again', () async {
      final result = await importBody('11/10/2026,100,expense,Pets,Cash');
      await repo.undo(result.batchId!);

      expect(
        () => repo.undo(result.batchId!),
        throwsA(isA<ValidationException>()),
      );
    });

    test('the balance goes back to what it was', () async {
      final cash = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          name: 'Cash',
          type: AccountType.cash,
          openingBalance: const Value(1000),
        ),
      );
      Future<int> balance() async {
        final row = (await db.accountsDao.getWithFlows(cash))!;
        return calculateAccountBalance(
          openingBalance: row.account.openingBalance,
          flows: row.flows,
        );
      }

      final result = await importBody(
        '11/10/2026,100,expense,Food,Cash\n12/10/2026,300,income,Salary,Cash',
      );
      expect(await balance(), 1000 - 10000 + 30000);

      await repo.undo(result.batchId!);

      expect(await balance(), 1000);
    });

    test('the latest import is the one that can be undone first', () async {
      final first = await importBody(
        '11/10/2026,10,expense,Pets,Cash',
        file: 'a.csv',
      );
      final second = await importBody(
        '12/10/2026,20,expense,Pets,Cash',
        file: 'b.csv',
      );

      expect((await repo.watchLastBatch().first)!.fileName, 'b.csv');
      await repo.undo(second.batchId!);
      expect((await repo.watchLastBatch().first)!.id, first.batchId);
      await repo.undo(first.batchId!);
      expect(await repo.watchLastBatch().first, isNull);
    });

    test('undoing an older import leaves the newer one alone', () async {
      final first = await importBody('11/10/2026,10,expense,Pets,Cash');
      final second = await importBody('12/10/2026,20,expense,Pets,Cash');

      final undone = await repo.undo(first.batchId!);

      // The category is still used by the second import.
      expect(undone.categoriesHidden, 0);
      final left = await db.transactionsDao.getAll();
      expect(left.single.importBatchId, second.batchId);
    });
  });

  group('remembering the columns', () {
    ImportMapping mappingWith({int amount = 1}) => ImportMapping(
      columns: {ImportField.date: 0, ImportField.amount: amount},
      dateFormat: SheetDateFormat.yearMonthDay,
      typeSource: TypeSource.allExpense,
      defaultAccountId: 4,
    );

    test('a file with the same columns finds the mapping', () async {
      await repo.saveMapping(['Date', 'Amount', 'Note'], mappingWith());

      final found = await repo.savedMapping([
        ' date ',
        'AMOUNT',
        'note',
      ], columnCount: 3);

      expect(found!.columns, mappingWith().columns);
      expect(found.dateFormat, SheetDateFormat.yearMonthDay);
      expect(found.defaultAccountId, 4);
    });

    test('a file with other columns does not', () async {
      await repo.saveMapping(['Date', 'Amount'], mappingWith());

      expect(
        await repo.savedMapping(['Date', 'Total'], columnCount: 2),
        isNull,
      );
      expect(
        await repo.savedMapping(['Amount', 'Date'], columnCount: 2),
        isNull,
      );
    });

    test('a mapping that does not fit the columns is not used', () async {
      await repo.saveMapping(['Date', 'A', 'B'], mappingWith(amount: 2));

      expect(
        await repo.savedMapping(['Date', 'A', 'B'], columnCount: 2),
        isNull,
      );
    });

    test('saving again for the same columns replaces it', () async {
      await repo.saveMapping(['Date', 'Amount'], mappingWith());
      await repo.saveMapping(['Date', 'Amount'], mappingWith(amount: 0));

      final found = await repo.savedMapping(['Date', 'Amount'], columnCount: 2);
      expect(found!.columns[ImportField.amount], 0);
    });

    test('only the last few layouts are kept', () async {
      for (var i = 0; i < maxSavedMappings + 1; i++) {
        await repo.saveMapping(['Date', 'Amount $i'], mappingWith());
      }

      expect(
        await repo.savedMapping(['Date', 'Amount 0'], columnCount: 2),
        isNull,
      );
      expect(
        await repo.savedMapping([
          'Date',
          'Amount $maxSavedMappings',
        ], columnCount: 2),
        isNotNull,
      );
      expect(
        await repo.savedMapping(['Date', 'Amount 1'], columnCount: 2),
        isNotNull,
      );
    });

    test('a damaged setting is ignored', () async {
      await db.settingsDao.put(importMappingsKey, 'not json');

      expect(
        await repo.savedMapping(['Date', 'Amount'], columnCount: 2),
        isNull,
      );
      // And saving writes a good one over it.
      await repo.saveMapping(['Date', 'Amount'], mappingWith());
      expect(
        await repo.savedMapping(['Date', 'Amount'], columnCount: 2),
        isNotNull,
      );
    });
  });

  test('deleting everything forgets the imports too', () async {
    await importBody('11/10/2026,100,expense,Pets,Cash');
    expect(await batches(), hasLength(1));

    await BackupRepository(db).eraseEverything();

    expect(await batches(), isEmpty);
  });
}
