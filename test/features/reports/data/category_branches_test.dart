import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int cash;
  late int bkash;
  late int food;
  late int bazar;
  late int fish;
  late int rent;
  late int salary;
  final october = monthRange(DateTime(2026, 10));

  setUp(() async {
    db = createTestDatabase();
    repo = ReportsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    bazar = await insertTestCategory(db, name: 'Kacha bazar', parentId: food);
    fish = await insertTestCategory(db, name: 'Fish', parentId: bazar);
    rent = await insertTestCategory(db, name: 'Rent');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<void> add(
    TransactionType type,
    int amount,
    int category, {
    DateTime? date,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: cash,
      categoryId: Value(category),
      date: date ?? DateTime(2026, 10, 5),
      isAdjustment: Value(adjustment),
    ),
  );

  CategoryBranch find(List<CategoryBranch> list, int id) =>
      flattenBranches(list).singleWhere((b) => b.category.id == id);

  test('rolls the spending up the tree', () async {
    await add(TransactionType.expense, 20000, fish);
    await add(TransactionType.expense, 5000, bazar);
    await add(TransactionType.expense, 1000, food);
    await add(TransactionType.expense, 40000, rent);

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );

    expect(find(branches, fish).total, 20000);
    expect(find(branches, bazar).own, 5000);
    expect(find(branches, bazar).total, 25000);
    expect(find(branches, food).own, 1000);
    expect(find(branches, food).total, 26000);
    expect(branches.map((b) => b.category.id), [rent, food]);
  });

  test('adds up many transactions on one category', () async {
    await add(TransactionType.expense, 100, fish);
    await add(TransactionType.expense, 250, fish);
    await add(TransactionType.expense, 50, fish);

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );

    expect(find(branches, fish).own, 400);
  });

  test('counts only the period', () async {
    await add(TransactionType.expense, 100, fish, date: DateTime(2026, 9, 30));
    await add(TransactionType.expense, 200, fish, date: DateTime(2026, 10, 1));
    await add(
      TransactionType.expense,
      400,
      fish,
      date: DateTime(2026, 10, 31, 23),
    );
    await add(TransactionType.expense, 800, fish, date: DateTime(2026, 11));

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );

    expect(find(branches, fish).own, 600);
  });

  test('keeps income and expense apart', () async {
    await add(TransactionType.expense, 100, fish);
    await add(TransactionType.income, 90000, salary);

    final expense = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );
    final income = await repo.categoryBranches(october, TransactionType.income);

    expect(flattenBranches(expense).map((b) => b.category.id), [
      food,
      bazar,
      fish,
    ]);
    expect(income.single.category.id, salary);
    expect(income.single.total, 90000);
  });

  test('leaves out balance corrections and transfers', () async {
    await add(TransactionType.expense, 100, fish);
    await add(TransactionType.expense, 7777, fish, adjustment: true);
    await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.transfer,
        amount: 5000,
        accountId: cash,
        toAccountId: Value(bkash),
        date: DateTime(2026, 10, 5),
      ),
    );

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );

    expect(find(branches, fish).own, 100);
    expect(branches.fold<int>(0, (s, b) => s + b.total), 100);
  });

  test('still shows a category that was archived since', () async {
    await add(TransactionType.expense, 300, fish);
    await db.categoriesDao.setArchived(fish, archived: true);

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );

    expect(find(branches, fish).own, 300);
    expect(find(branches, food).total, 300);
  });

  test('matches the top-level totals of the pie', () async {
    await add(TransactionType.expense, 20000, fish);
    await add(TransactionType.expense, 1000, food);
    await add(TransactionType.expense, 40000, rent);

    final branches = await repo.categoryBranches(
      october,
      TransactionType.expense,
    );
    final pie = await repo.expenseByCategory(october);

    expect(
      {for (final b in branches) b.category.id: b.total},
      {for (final p in pie) p.categoryId: p.total},
    );
  });

  test('is empty with nothing in the period', () async {
    expect(
      await repo.categoryBranches(october, TransactionType.expense),
      isEmpty,
    );
  });

  test('the report carries the branches', () async {
    await add(TransactionType.expense, 20000, fish);
    await add(TransactionType.income, 90000, salary);

    final report = await repo.loadReport(october);

    expect(report.expenseBranches.single.category.id, food);
    expect(report.incomeBranches.single.category.id, salary);
  });
}
