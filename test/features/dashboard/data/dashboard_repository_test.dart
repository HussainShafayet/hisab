import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/dashboard/data/dashboard_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

// Sunday 11 October 2026, 14:30. The week runs Sunday 11 to Saturday 17 Oct.
final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late DashboardRepository repo;
  late int cash;
  late int bkash;
  late int food;
  late int transport;
  late int rent;
  late int shopping;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = DashboardRepository(db);
    cash = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: const Value(100000),
      ),
    );
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    transport = await insertTestCategory(db, name: 'Transport');
    rent = await insertTestCategory(db, name: 'Rent');
    shopping = await insertTestCategory(db, name: 'Shopping');
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

  Future<void> expense(int category, int amount, DateTime date) =>
      add(TransactionType.expense, amount, date, category: category);

  test('is empty but complete with no transactions', () async {
    final data = await repo.load(now);

    expect(data.month, DateTime(2026, 10));
    expect(data.monthTotals.income, 0);
    expect(data.monthTotals.expense, 0);
    expect(data.totalBalance, 100000); // the opening balance of Cash
    expect(data.overallBudget, isNull);
    expect(data.todayExpense, 0);
    expect(data.weekExpense, 0);
    expect(data.topCategories, isEmpty);
    expect(data.recent, isEmpty);
  });

  test(
    'shows this month income and expense without transfers and corrections',
    () async {
      await add(
        TransactionType.income,
        5000000,
        DateTime(2026, 10, 1),
        category: salary,
      );
      await expense(food, 120000, DateTime(2026, 10, 5));
      await add(
        TransactionType.transfer,
        999999,
        DateTime(2026, 10, 6),
        toAccount: bkash,
      );
      await add(
        TransactionType.expense,
        88888,
        DateTime(2026, 10, 7),
        category: food,
        adjustment: true,
      );
      await expense(food, 77777, DateTime(2026, 9, 30)); // last month

      final data = await repo.load(now);

      expect(data.monthTotals.income, 5000000);
      expect(data.monthTotals.expense, 120000);
      expect(data.monthTotals.net, 4880000);
    },
  );

  test(
    'the total balance counts every transaction, corrections included',
    () async {
      await add(
        TransactionType.income,
        50000,
        DateTime(2026, 10, 1),
        category: salary,
      );
      await expense(food, 20000, DateTime(2026, 10, 2));
      // A correction changes the balance, though not income or expense.
      await add(
        TransactionType.income,
        7000,
        DateTime(2026, 10, 3),
        category: salary,
        adjustment: true,
      );
      await add(
        TransactionType.transfer,
        30000,
        DateTime(2026, 10, 4),
        toAccount: bkash,
      );

      final data = await repo.load(now);

      // Cash: 1,000 + 500 - 200 + 70 - 300. bKash gets the 300 transferred.
      expect(data.totalBalance, 100000 + 50000 - 20000 + 7000 - 30000 + 30000);
    },
  );

  test('today and this week count expenses only, from Sunday', () async {
    await expense(
      food,
      1,
      DateTime(2026, 10, 10, 23, 59, 59),
    ); // Saturday, last week
    await expense(
      food,
      10,
      DateTime(2026, 10, 11, 8),
    ); // Sunday, today, earlier
    await expense(food, 100, DateTime(2026, 10, 11, 20)); // today, later
    await expense(
      food,
      1000,
      DateTime(2026, 10, 14),
    ); // Wednesday, later this week
    await expense(food, 10000, DateTime(2026, 10, 18)); // next week
    await add(
      TransactionType.income,
      99999,
      DateTime(2026, 10, 11, 9),
      category: salary,
    );

    final data = await repo.load(now);

    // Today is the whole day, even the part after "now".
    expect(data.todayExpense, 110);
    expect(data.weekExpense, 1110);
  });

  group('the first day of the week', () {
    // Saturday 10 and Sunday 11 October (today), then Monday 12.
    setUp(() async {
      await expense(food, 1, DateTime(2026, 10, 9, 12)); // Friday
      await expense(food, 10, DateTime(2026, 10, 10, 12)); // Saturday
      await expense(food, 100, DateTime(2026, 10, 11, 12)); // Sunday, today
      await expense(food, 1000, DateTime(2026, 10, 12, 12)); // Monday
    });

    test('is Sunday unless said otherwise', () async {
      final data = await repo.load(now);

      // Sunday 11 to Saturday 17.
      expect(data.weekExpense, 1100);
    });

    test('can be Saturday', () async {
      final data = await repo.load(now, firstWeekday: DateTime.saturday);

      // Saturday 10 to Friday 16.
      expect(data.weekExpense, 1110);
    });

    test('can be Monday', () async {
      final data = await repo.load(now, firstWeekday: DateTime.monday);

      // Monday 5 to Sunday 11: today is the last day of the week.
      expect(data.weekExpense, 111);
    });

    test('does not change what today or the month show', () async {
      final sunday = await repo.load(now);
      final monday = await repo.load(now, firstWeekday: DateTime.monday);

      expect(monday.todayExpense, sunday.todayExpense);
      expect(monday.monthTotals.expense, sunday.monthTotals.expense);
    });
  });

  test('the week reaches back into the month before', () async {
    final thursday = DateTime(2026, 10, 1, 12);
    await expense(food, 5, DateTime(2026, 9, 27, 9)); // Sunday of that week
    await expense(food, 50, DateTime(2026, 9, 26)); // Saturday before

    final data = await repo.load(thursday);

    expect(data.weekExpense, 5);
  });

  test(
    'picks the three categories with the most spending this month',
    () async {
      await expense(food, 100, DateTime(2026, 10, 2));
      await expense(transport, 400, DateTime(2026, 10, 3));
      await expense(rent, 1200, DateTime(2026, 10, 4));
      await expense(shopping, 250, DateTime(2026, 10, 5));
      await expense(shopping, 9999, DateTime(2026, 9, 5)); // last month

      final data = await repo.load(now);

      expect(data.topCategories.map((c) => c.name), [
        'Rent',
        'Transport',
        'Shopping',
      ]);
      expect(data.topCategories.map((c) => c.total), [1200, 400, 250]);
    },
  );

  test('shows the latest five transactions of any kind', () async {
    for (var i = 1; i <= 4; i++) {
      await expense(food, i, DateTime(2026, 10, i));
    }
    await add(
      TransactionType.transfer,
      50,
      DateTime(2026, 10, 8),
      toAccount: bkash,
    );
    await add(
      TransactionType.income,
      60,
      DateTime(2026, 10, 9),
      category: salary,
    );
    await expense(food, 70, DateTime(2026, 9, 1)); // older

    final data = await repo.load(now);

    expect(data.recent.map((t) => t.amount), [60, 50, 4, 3, 2]);
  });

  test('has the budget of this month with what was spent', () async {
    await db.budgetsDao.insertBudget(
      BudgetsCompanion.insert(month: '2026-10', amount: 3000000),
    );
    await db.budgetsDao.insertBudget(
      BudgetsCompanion.insert(month: '2026-09', amount: 1),
    );
    await expense(food, 750000, DateTime(2026, 10, 3));

    final budget = (await repo.load(now)).overallBudget!;

    expect(budget.limit, 3000000);
    expect(budget.spent, 750000);
    expect(budget.progress.percent, 25);
  });

  test('has no budget when only a category budget is set', () async {
    await db.budgetsDao.insertBudget(
      BudgetsCompanion.insert(
        month: '2026-10',
        amount: 100,
        categoryId: Value(food),
      ),
    );

    expect((await repo.load(now)).overallBudget, isNull);
  });
}
