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
  late int salary;
  late int bonus;

  final october = monthRange(DateTime(2026, 10));

  setUp(() async {
    db = createTestDatabase();
    repo = ReportsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
    bonus = await insertTestCategory(
      db,
      name: 'Bonus',
      type: CategoryType.income,
      parentId: salary,
    );
  });
  tearDown(() => db.close());

  Future<void> add(
    TransactionType type,
    int amount,
    DateTime date, {
    required int account,
    int? category,
    int? toAccount,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: account,
      categoryId: Value(category),
      toAccountId: Value(toAccount),
      date: date,
      isAdjustment: Value(adjustment),
    ),
  );

  group('income by category', () {
    test('groups income by top-level category, biggest first, sub-categories included', () async {
      await add(
        TransactionType.income,
        5000000,
        DateTime(2026, 10, 1),
        account: cash,
        category: salary,
      );
      await add(
        TransactionType.income,
        700000,
        DateTime(2026, 10, 2),
        account: cash,
        category: bonus,
      );

      final totals = await repo.incomeByCategory(october);

      expect(totals.map((t) => (t.name, t.total)), [('Salary', 5700000)]);
    });

    test('leaves out expenses, corrections and other months', () async {
      await add(
        TransactionType.expense,
        999,
        DateTime(2026, 10, 2),
        account: cash,
        category: food,
      );
      await add(
        TransactionType.income,
        999,
        DateTime(2026, 10, 3),
        account: cash,
        category: salary,
        adjustment: true,
      );
      await add(
        TransactionType.income,
        999,
        DateTime(2026, 9, 30),
        account: cash,
        category: salary,
      );

      expect(await repo.incomeByCategory(october), isEmpty);
    });

    test('does not change what spending by category shows', () async {
      await add(
        TransactionType.income,
        5000,
        DateTime(2026, 10, 1),
        account: cash,
        category: salary,
      );
      await add(
        TransactionType.expense,
        700,
        DateTime(2026, 10, 2),
        account: cash,
        category: food,
      );

      final spending = await repo.expenseByCategory(october);

      expect(spending.map((t) => (t.name, t.total)), [('Food', 700)]);
    });
  });

  group('accounts', () {
    test(
      'adds up income and expense of each account, the busiest first',
      () async {
        await add(
          TransactionType.income,
          100000,
          DateTime(2026, 10, 1),
          account: cash,
          category: salary,
        );
        await add(
          TransactionType.expense,
          30000,
          DateTime(2026, 10, 2),
          account: cash,
          category: food,
        );
        await add(
          TransactionType.expense,
          500000,
          DateTime(2026, 10, 3),
          account: bkash,
          category: food,
        );

        final totals = await repo.accountTotals(october);

        expect(totals.map((t) => t.name), ['bKash', 'Cash']);
        expect((totals.last.income, totals.last.expense), (100000, 30000));
        expect((totals.first.income, totals.first.expense), (0, 500000));
      },
    );

    test(
      'leaves out transfers, corrections, other months and unused accounts',
      () async {
        await add(
          TransactionType.transfer,
          999,
          DateTime(2026, 10, 2),
          account: cash,
          toAccount: bkash,
        );
        await add(
          TransactionType.expense,
          999,
          DateTime(2026, 10, 3),
          account: cash,
          category: food,
          adjustment: true,
        );
        await add(
          TransactionType.expense,
          999,
          DateTime(2026, 9, 3),
          account: bkash,
          category: food,
        );

        expect(await repo.accountTotals(october), isEmpty);
      },
    );
  });

  test('the report holds both, with the rest of it unchanged', () async {
    await add(
      TransactionType.income,
      5000,
      DateTime(2026, 10, 1),
      account: cash,
      category: salary,
    );
    await add(
      TransactionType.expense,
      700,
      DateTime(2026, 10, 2),
      account: cash,
      category: food,
    );

    final report = await repo.loadReport(october);

    expect(report.totals.income, 5000);
    expect(report.categories.single.name, 'Food');
    expect(report.incomeCategories.single.name, 'Salary');
    expect(report.accounts.single.name, 'Cash');
  });
}
