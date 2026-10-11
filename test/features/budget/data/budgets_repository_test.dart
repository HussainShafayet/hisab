import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final october = DateTime(2026, 10);
final september = DateTime(2026, 9);

void main() {
  late AppDatabase db;
  late BudgetsRepository repo;
  late int cash;
  late int food;
  late int transport;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = BudgetsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
    transport = await insertTestCategory(db, name: 'Transport');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<void> spend(int category, int amount, DateTime date) =>
      db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: amount,
          accountId: cash,
          categoryId: Value(category),
          date: date,
        ),
      );

  Future<MonthBudget> month(DateTime m) => repo.watchMonth(m).first;

  group('setting a budget', () {
    test('sets an overall budget and a category budget', () async {
      await repo.setBudget(month: october, amount: 3000000);
      await repo.setBudget(month: october, amount: 800000, categoryId: food);

      final budget = await month(october);

      expect(budget.overall!.limit, 3000000);
      expect(budget.overall!.categoryId, isNull);
      expect(budget.categories.single.limit, 800000);
      expect(budget.categories.single.categoryName, 'Food');
    });

    test(
      'setting it again changes the limit instead of adding another',
      () async {
        await repo.setBudget(month: october, amount: 100);
        await repo.setBudget(month: october, amount: 250);
        await repo.setBudget(month: october, amount: 10, categoryId: food);
        await repo.setBudget(month: october, amount: 20, categoryId: food);

        final budget = await month(october);

        expect(budget.overall!.limit, 250);
        expect(budget.categories, hasLength(1));
        expect(budget.categories.single.limit, 20);
      },
    );

    test('budgets of other months do not mix', () async {
      await repo.setBudget(month: october, amount: 100);
      await repo.setBudget(month: september, amount: 999);

      expect((await month(october)).overall!.limit, 100);
      expect((await month(september)).overall!.limit, 999);
      expect((await month(DateTime(2026, 11))).isEmpty, isTrue);
    });

    test('any day of the month finds the same budget', () async {
      await repo.setBudget(month: DateTime(2026, 10, 20, 15), amount: 100);

      expect((await month(DateTime(2026, 10, 1))).overall!.limit, 100);
      expect((await month(DateTime(2026, 10, 31, 23))).overall!.limit, 100);
    });

    test('rejects a limit of zero or less', () async {
      expect(
        () => repo.setBudget(month: october, amount: 0),
        throwsValidation('above zero'),
      );
      expect(
        () => repo.setBudget(month: october, amount: -1),
        throwsValidation('above zero'),
      );
    });

    test(
      'rejects an income category, a missing one and an archived one',
      () async {
        expect(
          () => repo.setBudget(month: october, amount: 100, categoryId: salary),
          throwsValidation('expense category'),
        );
        expect(
          () => repo.setBudget(month: october, amount: 100, categoryId: 999),
          throwsValidation('not found'),
        );
        await db.categoriesDao.setArchived(transport, archived: true);
        expect(
          () => repo.setBudget(
            month: october,
            amount: 100,
            categoryId: transport,
          ),
          throwsValidation('archived'),
        );
      },
    );

    test(
      'the limit of a category that was archived later can still be changed',
      () async {
        await repo.setBudget(month: october, amount: 100, categoryId: food);
        await db.categoriesDao.setArchived(food, archived: true);

        await repo.setBudget(month: october, amount: 500, categoryId: food);

        expect((await month(october)).categories.single.limit, 500);
      },
    );
  });

  group('reading a month', () {
    test('shows what was spent against each budget', () async {
      await repo.setBudget(month: october, amount: 100000);
      await repo.setBudget(month: october, amount: 20000, categoryId: food);
      await spend(food, 5000, DateTime(2026, 10, 3));
      await spend(transport, 3000, DateTime(2026, 10, 4));
      await spend(food, 9999, DateTime(2026, 9, 30)); // last month

      final budget = await month(october);

      expect(budget.overall!.spent, 8000);
      expect(budget.overall!.progress.remaining, 92000);
      expect(budget.categories.single.spent, 5000);
      expect(budget.categories.single.progress.percent, 25);
    });

    test('lists the most used up category first', () async {
      await repo.setBudget(month: october, amount: 10000, categoryId: food);
      await repo.setBudget(
        month: october,
        amount: 10000,
        categoryId: transport,
      );
      await spend(food, 2000, DateTime(2026, 10, 3));
      await spend(transport, 9000, DateTime(2026, 10, 4));

      final names = (await month(october)).categories
          .map((c) => c.categoryName);

      expect(names, ['Transport', 'Food']);
    });

    test('updates when an expense is added', () async {
      await repo.setBudget(month: october, amount: 100000);
      final spent = <int>[];
      final subscription = repo
          .watchMonth(october)
          .listen((b) => spent.add(b.overall!.spent));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await spend(food, 4200, DateTime(2026, 10, 9));
      await pumpEventQueue();

      expect(spent.first, 0);
      expect(spent.last, 4200);
    });

    test('updates when the budget is changed', () async {
      await repo.setBudget(month: october, amount: 100);
      final limits = <int>[];
      final subscription = repo
          .watchMonth(october)
          .listen((b) => limits.add(b.overall!.limit));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repo.setBudget(month: october, amount: 300);
      await pumpEventQueue();

      expect(limits.first, 100);
      expect(limits.last, 300);
    });
  });

  group('removing a budget', () {
    test('removes only that budget', () async {
      await repo.setBudget(month: october, amount: 100);
      await repo.setBudget(month: october, amount: 50, categoryId: food);
      final overall = (await month(october)).overall!;

      await repo.removeBudget(overall.id);

      final budget = await month(october);
      expect(budget.overall, isNull);
      expect(budget.categories, hasLength(1));
    });
  });

  group('copying last month', () {
    test('copies every budget into the month', () async {
      await repo.setBudget(month: september, amount: 3000000);
      await repo.setBudget(month: september, amount: 800000, categoryId: food);
      await repo.setBudget(
        month: september,
        amount: 200000,
        categoryId: transport,
      );

      final copied = await repo.copyFromPreviousMonth(october);

      expect(copied, 3);
      final budget = await month(october);
      expect(budget.overall!.limit, 3000000);
      expect(
        budget.categories.map((c) => c.limit),
        unorderedEquals([800000, 200000]),
      );
      // Last month is untouched.
      expect((await month(september)).categories, hasLength(2));
    });

    test('leaves a budget the month already has as it is', () async {
      await repo.setBudget(month: september, amount: 3000000);
      await repo.setBudget(month: september, amount: 800000, categoryId: food);
      await repo.setBudget(month: october, amount: 111);

      final copied = await repo.copyFromPreviousMonth(october);

      expect(copied, 1);
      final budget = await month(october);
      expect(budget.overall!.limit, 111);
      expect(budget.categories.single.limit, 800000);
    });

    test('copying again copies nothing new', () async {
      await repo.setBudget(month: september, amount: 100);
      await repo.copyFromPreviousMonth(october);

      expect(await repo.copyFromPreviousMonth(october), 0);
      expect((await month(october)).overall!.limit, 100);
    });

    test('skips the budget of an archived category', () async {
      await repo.setBudget(month: september, amount: 100, categoryId: food);
      await repo.setBudget(
        month: september,
        amount: 200,
        categoryId: transport,
      );
      await db.categoriesDao.setArchived(food, archived: true);

      final copied = await repo.copyFromPreviousMonth(october);

      expect(copied, 1);
      expect(
        (await month(october)).categories.single.categoryName,
        'Transport',
      );
    });

    test('says so when last month has no budget', () async {
      expect(
        () => repo.copyFromPreviousMonth(october),
        throwsValidation('September 2026'),
      );
    });

    test('takes January from the December before', () async {
      await repo.setBudget(month: DateTime(2025, 12), amount: 777);

      expect(await repo.copyFromPreviousMonth(DateTime(2026, 1)), 1);
      expect((await month(DateTime(2026, 1))).overall!.limit, 777);
    });

    test('copies at any day of the month', () async {
      await repo.setBudget(month: september, amount: 100);

      expect(await repo.copyFromPreviousMonth(DateTime(2026, 10, 20, 9)), 1);
      expect((await month(october)).overall!.limit, 100);
    });
  });
}
