import 'package:drift/drift.dart' show InvalidDataException, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

BudgetsCompanion budget(String month, int amount, {int? categoryId}) =>
    BudgetsCompanion.insert(
      month: month,
      amount: amount,
      categoryId: Value(categoryId),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('keeps an overall budget and category budgets side by side', () async {
    final food = await insertTestCategory(db, name: 'Food');
    await db.budgetsDao.insertBudget(budget('2026-10', 3000000));
    await db.budgetsDao.insertBudget(
      budget('2026-10', 800000, categoryId: food),
    );
    await db.budgetsDao.insertBudget(budget('2026-11', 2500000));

    final october = await db.budgetsDao.getForMonth('2026-10');

    expect(october.map((b) => b.categoryId), [null, food]);
    expect(october.map((b) => b.amount), [3000000, 800000]);
  });

  test('allows one overall budget per month', () async {
    await db.budgetsDao.insertBudget(budget('2026-10', 3000000));

    expect(
      () => db.budgetsDao.insertBudget(budget('2026-10', 1)),
      throwsConstraint('UNIQUE'),
    );
  });

  test('allows one budget per category per month', () async {
    final food = await insertTestCategory(db, name: 'Food');
    final rent = await insertTestCategory(db, name: 'Rent');
    await db.budgetsDao.insertBudget(budget('2026-10', 100, categoryId: food));

    await db.budgetsDao.insertBudget(budget('2026-10', 100, categoryId: rent));
    await db.budgetsDao.insertBudget(budget('2026-11', 100, categoryId: food));

    expect(
      () =>
          db.budgetsDao.insertBudget(budget('2026-10', 200, categoryId: food)),
      throwsConstraint('UNIQUE'),
    );
  });

  test('rejects a zero or negative amount', () async {
    expect(
      () => db.budgetsDao.insertBudget(budget('2026-10', 0)),
      throwsConstraint('CHECK'),
    );
    expect(
      () => db.budgetsDao.insertBudget(budget('2026-10', -5)),
      throwsConstraint('CHECK'),
    );
  });

  test('rejects a month that is not YYYY-MM sized', () async {
    expect(
      () => db.budgetsDao.insertBudget(budget('2026-1', 100)),
      throwsA(isA<InvalidDataException>()),
    );
  });

  test('rejects an unknown category', () async {
    expect(
      () => db.budgetsDao.insertBudget(budget('2026-10', 100, categoryId: 99)),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('updates and deletes a budget', () async {
    final id = await db.budgetsDao.insertBudget(budget('2026-10', 100));
    final row = (await db.budgetsDao.getForMonth('2026-10')).single;

    await db.budgetsDao.updateBudget(row.copyWith(amount: 250));
    expect((await db.budgetsDao.getForMonth('2026-10')).single.amount, 250);

    expect(await db.budgetsDao.deleteBudget(id), 1);
    expect(await db.budgetsDao.getForMonth('2026-10'), isEmpty);
  });

  group('with what was spent', () {
    late int cash;
    late int bkash;
    late int food;
    late int groceries;
    late int snacks;
    late int transport;
    late int salary;

    final start = DateTime(2026, 10);
    final end = DateTime(2026, 11);

    setUp(() async {
      cash = await insertTestAccount(db, name: 'Cash');
      bkash = await insertTestAccount(db, name: 'bKash');
      food = await insertTestCategory(db, name: 'Food');
      groceries = await insertTestCategory(
        db,
        name: 'Groceries',
        parentId: food,
      );
      snacks = await insertTestCategory(db, name: 'Snacks', parentId: food);
      transport = await insertTestCategory(db, name: 'Transport');
      salary = await insertTestCategory(
        db,
        name: 'Salary',
        type: CategoryType.income,
      );
    });

    Future<void> spend(
      int category,
      int amount,
      DateTime date, {
      TransactionType type = TransactionType.expense,
      bool adjustment = false,
    }) => db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: type,
        amount: amount,
        accountId: cash,
        categoryId: Value(category),
        date: date,
        isAdjustment: Value(adjustment),
      ),
    );

    Future<Map<int?, int>> spentByCategory() async {
      final rows = await db.budgetsDao.getForMonthWithSpent(
        '2026-10',
        start,
        end,
      );
      return {for (final row in rows) row.categoryId: row.spent};
    }

    test('the overall budget counts every expense of the month', () async {
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      await spend(food, 1000, DateTime(2026, 10, 5));
      await spend(transport, 250, DateTime(2026, 10, 20));

      expect((await spentByCategory())[null], 1250);
    });

    test('it leaves out income, transfers and balance adjustments', () async {
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      await spend(food, 1000, DateTime(2026, 10, 5));
      await spend(
        salary,
        999999,
        DateTime(2026, 10, 6),
        type: TransactionType.income,
      );
      await spend(food, 77777, DateTime(2026, 10, 7), adjustment: true);
      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.transfer,
          amount: 555555,
          accountId: cash,
          toAccountId: Value(bkash),
          date: DateTime(2026, 10, 8),
        ),
      );

      expect((await spentByCategory())[null], 1000);
    });

    test('it counts a transfer fee, which is an expense', () async {
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      final fees = await insertTestCategory(db, name: 'Fees & charges');
      await spend(fees, 1500, DateTime(2026, 10, 8));

      expect((await spentByCategory())[null], 1500);
    });

    test(
      'only the month counts: its first moment in, the next 1st out',
      () async {
        await db.budgetsDao.insertBudget(budget('2026-10', 100000));
        await spend(food, 1, DateTime(2026, 9, 30, 23, 59, 59));
        await spend(food, 10, DateTime(2026, 10)); // first moment of October
        await spend(food, 100, DateTime(2026, 10, 31, 23, 59, 59));
        await spend(food, 1000, DateTime(2026, 11)); // first moment of November

        expect((await spentByCategory())[null], 110);
      },
    );

    test(
      'a category budget counts its own and its sub-categories expenses',
      () async {
        await db.budgetsDao.insertBudget(
          budget('2026-10', 50000, categoryId: food),
        );
        await spend(food, 100, DateTime(2026, 10, 2));
        await spend(groceries, 200, DateTime(2026, 10, 3));
        await spend(snacks, 400, DateTime(2026, 10, 4));
        await spend(transport, 9999, DateTime(2026, 10, 5)); // another category

        expect((await spentByCategory())[food], 700);
      },
    );

    test('a sub-category budget counts only itself', () async {
      await db.budgetsDao.insertBudget(
        budget('2026-10', 50000, categoryId: groceries),
      );
      await spend(food, 100, DateTime(2026, 10, 2));
      await spend(groceries, 200, DateTime(2026, 10, 3));
      await spend(snacks, 400, DateTime(2026, 10, 4));

      expect((await spentByCategory())[groceries], 200);
    });

    test('a category budget leaves out its balance adjustments too', () async {
      await db.budgetsDao.insertBudget(
        budget('2026-10', 50000, categoryId: food),
      );
      await spend(food, 100, DateTime(2026, 10, 2));
      await spend(food, 5000, DateTime(2026, 10, 3), adjustment: true);

      expect((await spentByCategory())[food], 100);
    });

    test('is zero when nothing was spent', () async {
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      await db.budgetsDao.insertBudget(
        budget('2026-10', 5000, categoryId: transport),
      );

      final spent = await spentByCategory();
      expect(spent[null], 0);
      expect(spent[transport], 0);
    });

    test('carries the category name, icon and color', () async {
      await db.categoriesDao.updateCategory(
        (await db.categoriesDao.getById(transport))!
            .copyWith(icon: 'directions_bus', color: 0xFF42A5F5),
      );
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      await db.budgetsDao.insertBudget(
        budget('2026-10', 5000, categoryId: transport),
      );

      final rows = await db.budgetsDao.getForMonthWithSpent(
        '2026-10',
        start,
        end,
      );

      expect(rows.first.categoryId, isNull);
      expect(rows.first.categoryName, isNull);
      expect(rows.last.categoryName, 'Transport');
      expect(rows.last.categoryIcon, 'directions_bus');
      expect(rows.last.categoryColor, 0xFF42A5F5);
    });

    test('only returns the budgets of that month', () async {
      await db.budgetsDao.insertBudget(budget('2026-09', 111));
      await db.budgetsDao.insertBudget(budget('2026-10', 222));

      final rows = await db.budgetsDao.getForMonthWithSpent(
        '2026-10',
        start,
        end,
      );

      expect(rows.map((r) => r.amount), [222]);
    });

    test('emits again when an expense is added', () async {
      await db.budgetsDao.insertBudget(budget('2026-10', 100000));
      final spent = <int>[];
      final subscription = db.budgetsDao
          .watchForMonthWithSpent('2026-10', start, end)
          .listen((rows) => spent.add(rows.single.spent));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await spend(food, 1234, DateTime(2026, 10, 9));
      await pumpEventQueue();

      expect(spent.first, 0);
      expect(spent.last, 1234);
    });

    test('finds a budget by month and category', () async {
      final overall = await db.budgetsDao.insertBudget(budget('2026-10', 1));
      final forFood = await db.budgetsDao.insertBudget(
        budget('2026-10', 2, categoryId: food),
      );

      expect(
        (await db.budgetsDao.getByMonthAndCategory('2026-10', null))!.id,
        overall,
      );
      expect(
        (await db.budgetsDao.getByMonthAndCategory('2026-10', food))!.id,
        forFood,
      );
      expect(
        await db.budgetsDao.getByMonthAndCategory('2026-11', food),
        isNull,
      );
      expect(
        await db.budgetsDao.getByMonthAndCategory('2026-10', transport),
        isNull,
      );
    });
  });
}
