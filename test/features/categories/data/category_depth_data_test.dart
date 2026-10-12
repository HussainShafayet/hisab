import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

/// Categories that sit inside categories inside categories: reports, budgets,
/// backup and the CSV all have to follow them to the bottom.
///
///   Food
///   └ Groceries
///     └ Rice
///   Transport
void main() {
  late AppDatabase db;
  late int cash;
  late int food;
  late int groceries;
  late int rice;
  late int transport;

  final october = monthRange(DateTime(2026, 10));

  setUp(() async {
    db = createTestDatabase();
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
    groceries = await insertTestCategory(db, name: 'Groceries', parentId: food);
    rice = await insertTestCategory(db, name: 'Rice', parentId: groceries);
    transport = await insertTestCategory(db, name: 'Transport');
  });
  tearDown(() => db.close());

  Future<void> spend(int amount, int category, {int day = 5}) =>
      db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: amount,
          accountId: cash,
          categoryId: Value(category),
          date: DateTime(2026, 10, day, 12),
        ),
      );

  group('reports', () {
    test('spending at any depth counts for the top-level category', () async {
      await spend(100, food);
      await spend(200, groceries);
      await spend(400, rice);
      await spend(50, transport);

      final rows = await db.reportsDao.expenseByCategory(
        october.start,
        october.end,
      );

      expect(
        [for (final r in rows) (r.name, r.total)],
        [('Food', 700), ('Transport', 50)],
      );
    });
  });

  group('budgets', () {
    Future<Map<int?, int>> spentByBudget() async {
      final rows = await db.budgetsDao.getForMonthWithSpent(
        '2026-10',
        october.start,
        october.end,
      );
      return {for (final r in rows) r.categoryId: r.spent};
    }

    test('a category budget counts everything inside the category', () async {
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 1000,
          categoryId: Value(food),
        ),
      );
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 1000,
          categoryId: Value(groceries),
        ),
      );
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 1000,
          categoryId: Value(rice),
        ),
      );
      await spend(100, food);
      await spend(200, groceries);
      await spend(400, rice);
      await spend(50, transport);

      final spent = await spentByBudget();

      expect(spent[food], 700);
      expect(spent[groceries], 600);
      expect(spent[rice], 400);
    });

    test('the overall budget still counts every expense', () async {
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(month: '2026-10', amount: 5000),
      );
      await spend(100, food);
      await spend(400, rice);
      await spend(50, transport);

      expect((await spentByBudget())[null], 550);
    });
  });

  group('backup', () {
    test('a backup keeps the nesting and restores it parents first', () async {
      await spend(400, rice);
      final backup = await BackupRepository(db).buildBackup(DateTime(2026, 10));
      final other = createTestDatabase();
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final restored = await other.categoriesDao.getAll();
      final byName = {for (final c in restored) c.name: c};
      expect(byName['Rice']!.parentId, byName['Groceries']!.id);
      expect(byName['Groceries']!.parentId, byName['Food']!.id);
      expect(byName['Food']!.parentId, isNull);
      expect((await other.transactionsDao.getAll()).single.categoryId, rice);
    });

    test('restoring over nested categories removes them all', () async {
      final empty = createTestDatabase();
      addTearDown(empty.close);
      await insertTestAccount(empty, name: 'Bank');
      final backup = await BackupRepository(empty).buildBackup(DateTime(2026));

      await BackupRepository(db).restore(backup);

      expect(await db.categoriesDao.getAll(includeArchived: true), isEmpty);
    });

    test('restoring a backup whose rows are not in nesting order', () async {
      final backup = await BackupRepository(db).buildBackup(DateTime(2026, 10));
      // Rice (the innermost) first, Food (the top) last.
      final reversed = backup.categories.reversed.toList();
      final shuffled = BackupData(
        exportedAt: backup.exportedAt,
        accounts: backup.accounts,
        categories: reversed,
        transactions: backup.transactions,
        budgets: backup.budgets,
      );
      final other = createTestDatabase();
      addTearDown(other.close);

      await BackupRepository(other).restore(shuffled);

      expect(await other.categoriesDao.getAll(), hasLength(4));
    });
  });

  group('CSV', () {
    Future<String> exportedCategories() async {
      await spend(400, rice);
      final text = await BackupRepository(db).exportTransactionsCsv();
      return parseCsvTable(text, hasHeader: false).rows[1][5];
    }

    Future<ImportPlan> planFor(AppDatabase target, String csv) async {
      final table = parseCsvTable(csv);
      return buildImportPlan(
        table: table,
        mapping: ImportMapping(
          columns: guessColumns(table.headers),
          dateFormat: SheetDateFormat.yearMonthDay,
          typeSource: TypeSource.column,
        ),
        context: await CsvImportRepository(target).loadContext(),
      );
    }

    const sheet =
        'Date,Type,Amount,Account,Category\n'
        '2026-10-05,expense,40,Cash,Food > Groceries > Rice\n';

    test('the export writes the whole path', () async {
      expect(await exportedCategories(), 'Food > Groceries > Rice');
    });

    test('the import makes every missing level', () async {
      final target = createTestDatabase();
      addTearDown(target.close);

      final plan = await planFor(target, sheet);
      final result = await CsvImportRepository(target).apply(plan);

      expect(plan.errorCount, 0);
      expect(result.categoriesCreated, 3);
      final all = {
        for (final c in await target.categoriesDao.getAll()) c.name: c,
      };
      expect(all['Food']!.parentId, isNull);
      expect(all['Groceries']!.parentId, all['Food']!.id);
      expect(all['Rice']!.parentId, all['Groceries']!.id);
    });

    test('the import only makes the levels that are missing', () async {
      final plan = await planFor(db, sheet);

      expect(plan.importCount, 1);
      expect(plan.newCategories, isEmpty);

      final other = createTestDatabase();
      addTearDown(other.close);
      final foodId = await insertTestCategory(other, name: 'Food');
      await insertTestCategory(other, name: 'Groceries', parentId: foodId);
      final result = await CsvImportRepository(other)
          .apply(await planFor(other, sheet));

      expect(result.categoriesCreated, 1);
      final names = [
        for (final c in await other.categoriesDao.getAll()) c.name,
      ];
      expect(names, containsAll(['Food', 'Groceries', 'Rice']));
    });

    test('more than five levels is an unreadable row', () async {
      final plan = await planFor(
        db,
        'Date,Type,Amount,Account,Category\n'
        '2026-10-05,expense,40,Cash,A > B > C > D > E > F\n',
      );

      expect(plan.errorCount, 1);
      expect(plan.rows.single.error, contains('5 levels'));
    });
  });
}
