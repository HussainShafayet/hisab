import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int cash;
  late int bkash;
  late int food;
  late int groceries;
  late int snacks;
  late int transport;
  late int salary;

  final october = monthRange(DateTime(2026, 10));

  setUp(() async {
    db = createTestDatabase();
    repo = ReportsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    groceries = await insertTestCategory(db, name: 'Groceries', parentId: food);
    snacks = await insertTestCategory(db, name: 'Snacks', parentId: food);
    transport = await insertTestCategory(db, name: 'Transport');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<int> add(
    TransactionType type,
    int amount,
    DateTime date, {
    int? category,
    int? toAccount,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: cash,
      categoryId: Value(category),
      toAccountId: Value(toAccount),
      date: date,
      isAdjustment: Value(adjustment),
    ),
  );

  Future<int> expense(
    int category,
    int amount,
    DateTime date, {
    bool adjustment = false,
  }) => add(
    TransactionType.expense,
    amount,
    date,
    category: category,
    adjustment: adjustment,
  );

  group('totals', () {
    test('are zero for an empty period', () async {
      final totals = await repo.totals(october);

      expect(totals.income, 0);
      expect(totals.expense, 0);
      expect(totals.net, 0);
    });

    test('add up income and expense separately', () async {
      await add(
        TransactionType.income,
        5000000,
        DateTime(2026, 10, 1),
        category: salary,
      );
      await expense(food, 120000, DateTime(2026, 10, 5));
      await expense(transport, 30000, DateTime(2026, 10, 6));

      final totals = await repo.totals(october);

      expect(totals.income, 5000000);
      expect(totals.expense, 150000);
      expect(totals.net, 4850000);
    });

    test('leave out transfers', () async {
      await add(
        TransactionType.transfer,
        999999,
        DateTime(2026, 10, 3),
        toAccount: bkash,
      );
      await expense(food, 1000, DateTime(2026, 10, 4));

      final totals = await repo.totals(october);

      expect(totals.income, 0);
      expect(totals.expense, 1000);
    });

    test('leave out balance adjustments', () async {
      await add(
        TransactionType.income,
        77777,
        DateTime(2026, 10, 3),
        category: salary,
        adjustment: true,
      );
      await expense(food, 88888, DateTime(2026, 10, 4), adjustment: true);
      await expense(food, 1000, DateTime(2026, 10, 5));

      final totals = await repo.totals(october);

      expect(totals.income, 0);
      expect(totals.expense, 1000);
    });

    test('include the first moment of the range and exclude its end', () async {
      await expense(food, 1, DateTime(2026, 9, 30, 23, 59, 59));
      await expense(food, 10, DateTime(2026, 10));
      await expense(food, 100, DateTime(2026, 10, 31, 23, 59, 59));
      await expense(food, 1000, DateTime(2026, 11));

      expect((await repo.totals(october)).expense, 110);
    });

    test('work for a custom range of days', () async {
      await expense(food, 5, DateTime(2026, 10, 4, 23, 59));
      await expense(food, 50, DateTime(2026, 10, 5));
      await expense(food, 500, DateTime(2026, 10, 9, 23, 59));
      await expense(food, 5000, DateTime(2026, 10, 10));

      final range = (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 10));

      expect((await repo.totals(range)).expense, 550);
    });
  });

  group('expense by category', () {
    test('adds a sub-category to its parent, biggest first', () async {
      await expense(food, 100, DateTime(2026, 10, 2));
      await expense(groceries, 200, DateTime(2026, 10, 3));
      await expense(snacks, 300, DateTime(2026, 10, 4));
      await expense(transport, 500, DateTime(2026, 10, 5));

      final categories = await repo.expenseByCategory(october);

      expect(categories.map((c) => c.name), ['Food', 'Transport']);
      expect(categories.map((c) => c.total), [600, 500]);
      expect(categories.first.categoryId, food);
    });

    test('carries the icon and color of the top-level category', () async {
      await db.categoriesDao.updateCategory(
        (await db.categoriesDao.getById(food))!
            .copyWith(icon: 'restaurant', color: 0xFFEF5350),
      );
      await expense(groceries, 200, DateTime(2026, 10, 3));

      final category = (await repo.expenseByCategory(october)).single;

      expect(category.icon, 'restaurant');
      expect(category.color, 0xFFEF5350);
    });

    test('ignores income, transfers, adjustments and other months', () async {
      await expense(food, 100, DateTime(2026, 10, 2));
      await add(
        TransactionType.income,
        9999,
        DateTime(2026, 10, 3),
        category: salary,
      );
      await add(
        TransactionType.transfer,
        9999,
        DateTime(2026, 10, 3),
        toAccount: bkash,
      );
      await expense(food, 9999, DateTime(2026, 10, 4), adjustment: true);
      await expense(food, 9999, DateTime(2026, 9, 30));

      final categories = await repo.expenseByCategory(october);

      expect(categories.single.total, 100);
    });

    test('is empty when nothing was spent', () async {
      expect(await repo.expenseByCategory(october), isEmpty);
    });

    test('still counts a category that was archived', () async {
      await expense(transport, 700, DateTime(2026, 10, 2));
      await db.categoriesDao.setArchived(transport, archived: true);

      expect((await repo.expenseByCategory(october)).single.total, 700);
    });
  });

  group('monthly totals', () {
    test(
      'lists the last months, oldest first, each with its own totals',
      () async {
        await expense(food, 100, DateTime(2026, 8, 15));
        await expense(food, 200, DateTime(2026, 9, 15));
        await add(
          TransactionType.income,
          5000,
          DateTime(2026, 10, 1),
          category: salary,
        );
        await expense(food, 300, DateTime(2026, 10, 15));

        final months = await repo.monthlyTotals(DateTime(2026, 10), count: 3);

        expect(months.map((m) => m.month), [
          DateTime(2026, 8),
          DateTime(2026, 9),
          DateTime(2026, 10),
        ]);
        expect(months.map((m) => m.totals.expense), [100, 200, 300]);
        expect(months.map((m) => m.totals.income), [0, 0, 5000]);
      },
    );

    test('shows six months by default, empty months as zero', () async {
      final months = await repo.monthlyTotals(DateTime(2026, 2));

      expect(months, hasLength(6));
      expect(months.first.month, DateTime(2025, 9));
      expect(months.last.month, DateTime(2026, 2));
      expect(months.every((m) => m.totals.net == 0), isTrue);
    });

    test('a month boundary is local midnight', () async {
      await expense(food, 1, DateTime(2026, 9, 30, 23, 59, 59));
      await expense(food, 10, DateTime(2026, 10));

      final months = await repo.monthlyTotals(DateTime(2026, 10), count: 2);

      expect(months.map((m) => m.totals.expense), [1, 10]);
    });
  });

  group('top expenses', () {
    test('lists the biggest single expenses first', () async {
      final small = await expense(food, 100, DateTime(2026, 10, 2));
      final big = await expense(transport, 900, DateTime(2026, 10, 3));
      final mid = await expense(food, 500, DateTime(2026, 10, 4));

      final top = await repo.topExpenses(october);

      expect(top.map((t) => t.id), [big, mid, small]);
      expect(top.first.categoryName, 'Transport');
      expect(top.first.accountName, 'Cash');
    });

    test('stops at the limit', () async {
      for (var i = 1; i <= 12; i++) {
        await expense(food, i * 100, DateTime(2026, 10, i));
      }

      final top = await repo.topExpenses(october);

      expect(top, hasLength(10));
      expect(top.first.amount, 1200);
      expect(top.last.amount, 300);
      expect(await repo.topExpenses(october, limit: 3), hasLength(3));
    });

    test('is not for income, transfers, adjustments or other months', () async {
      await expense(food, 100, DateTime(2026, 10, 2));
      await add(
        TransactionType.income,
        9999999,
        DateTime(2026, 10, 3),
        category: salary,
      );
      await add(
        TransactionType.transfer,
        9999999,
        DateTime(2026, 10, 3),
        toAccount: bkash,
      );
      await expense(food, 9999999, DateTime(2026, 10, 4), adjustment: true);
      await expense(food, 9999999, DateTime(2026, 9, 30));

      final top = await repo.topExpenses(october);

      expect(top.map((t) => t.amount), [100]);
    });

    test('equal amounts show the newest first', () async {
      final older = await expense(food, 500, DateTime(2026, 10, 2));
      final newer = await expense(food, 500, DateTime(2026, 10, 9));

      expect((await repo.topExpenses(october)).map((t) => t.id), [
        newer,
        older,
      ]);
    });
  });

  group('recent transactions', () {
    test('are the newest of any kind, from any month', () async {
      await expense(food, 1, DateTime(2026, 8, 1));
      final transfer = await add(
        TransactionType.transfer,
        2,
        DateTime(2026, 10, 9),
        toAccount: bkash,
      );
      final income = await add(
        TransactionType.income,
        3,
        DateTime(2026, 10, 10),
        category: salary,
      );

      final recent = await repo.recentTransactions(limit: 2);

      expect(recent.map((t) => t.id), [income, transfer]);
    });

    test('stop at five by default', () async {
      for (var i = 1; i <= 8; i++) {
        await expense(food, i, DateTime(2026, 10, i));
      }

      final recent = await repo.recentTransactions();

      expect(recent, hasLength(5));
      expect(recent.first.amount, 8);
      expect(recent.last.amount, 4);
    });

    test('include corrections, marked as such', () async {
      await expense(food, 5, DateTime(2026, 10, 3), adjustment: true);

      expect((await repo.recentTransactions()).single.isAdjustment, isTrue);
    });
  });

  group('a whole report', () {
    test('compares a month with the month before', () async {
      await expense(food, 300, DateTime(2026, 9, 10));
      await expense(food, 450, DateTime(2026, 10, 10));
      await expense(transport, 50, DateTime(2026, 10, 11));

      final report = await repo.loadReport(october);

      expect(report.totals.expense, 500);
      expect(report.previousTotals.expense, 300);
      expect(report.previousRange.start, DateTime(2026, 9));
      expect(report.previousRange.end, DateTime(2026, 10));
      expect(report.categories.map((c) => c.name), ['Food', 'Transport']);
      expect(report.topExpenses.first.amount, 450);
    });

    test('compares a custom range with the days right before it', () async {
      await expense(food, 70, DateTime(2026, 10, 3)); // before the range
      await expense(food, 200, DateTime(2026, 10, 7)); // in the range
      final range = (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 10));

      final report = await repo.loadReport(range);

      expect(report.totals.expense, 200);
      // The 5 days before: 30 Sep to 4 Oct.
      expect(report.previousRange.start, DateTime(2026, 9, 30));
      expect(report.previousTotals.expense, 70);
    });

    test('the chart ends with the month the range ends in', () async {
      final range = (start: DateTime(2026, 9, 20), end: DateTime(2026, 11, 3));

      final report = await repo.loadReport(range);

      expect(report.months, hasLength(6));
      expect(report.months.last.month, DateTime(2026, 11));
    });

    test('is empty but complete for a period with nothing in it', () async {
      final report = await repo.loadReport(october);

      expect(report.totals.net, 0);
      expect(report.categories, isEmpty);
      expect(report.topExpenses, isEmpty);
      expect(report.months, hasLength(6));
    });
  });
}
