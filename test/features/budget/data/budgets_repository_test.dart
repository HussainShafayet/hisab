import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
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

  group('the overall budget', () {
    test('is read with what was spent', () async {
      await repo.setBudget(month: october, amount: 100000);
      await repo.setBudget(month: october, amount: 20000, categoryId: food);
      await spend(food, 5000, DateTime(2026, 10, 3));
      await spend(transport, 3000, DateTime(2026, 10, 4));

      final overall = (await repo.overallBudget(DateTime(2026, 10, 20)))!;

      expect(overall.limit, 100000);
      expect(overall.spent, 8000);
      expect(overall.categoryId, isNull);
    });

    test(
      'is null when only a category budget or another month has one',
      () async {
        await repo.setBudget(month: october, amount: 100, categoryId: food);
        await repo.setBudget(month: september, amount: 100);

        expect(await repo.overallBudget(october), isNull);
      },
    );
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

  group('carrying over what is left', () {
    final august = DateTime(2026, 8);
    final november = DateTime(2026, 11);

    Future<void> rolloverOn() =>
        db.settingsDao.put(PreferenceKeys.budgetRollover, 'true');

    test('adds nothing while it is off', () async {
      await repo.setBudget(month: september, amount: 100000);
      await repo.setBudget(month: october, amount: 100000);
      await spend(food, 30000, DateTime(2026, 9, 10));

      final budget = (await repo.overallBudget(october))!;

      expect(budget.limit, 100000);
      expect(budget.carriedOver, 0);
    });

    test('adds what was not spent last month', () async {
      await rolloverOn();
      await repo.setBudget(month: september, amount: 100000);
      await repo.setBudget(month: october, amount: 100000);
      await spend(food, 60000, DateTime(2026, 9, 10));

      final fromStream = (await month(october)).overall!;
      final oneOff = (await repo.overallBudget(october))!;

      for (final budget in [fromStream, oneOff]) {
        expect(budget.carriedOver, 40000);
        expect(budget.limit, 140000);
        expect(budget.setAmount, 100000);
      }
    });

    test('passes a leftover on through several months', () async {
      await rolloverOn();
      await repo.setBudget(month: august, amount: 100000);
      await repo.setBudget(month: september, amount: 100000);
      await repo.setBudget(month: october, amount: 100000);
      await spend(food, 70000, DateTime(2026, 8, 5));
      await spend(food, 120000, DateTime(2026, 9, 5));

      // August leaves 30,000. September has 130,000 and spends 120,000, so
      // 10,000 goes on to October.
      final budget = (await repo.overallBudget(october))!;

      expect(budget.carriedOver, 10000);
      expect(budget.limit, 110000);
    });

    test('overspending takes nothing off the next month', () async {
      await rolloverOn();
      await repo.setBudget(month: september, amount: 100000);
      await repo.setBudget(month: october, amount: 100000);
      await spend(food, 150000, DateTime(2026, 9, 10));

      final budget = (await repo.overallBudget(october))!;

      expect(budget.carriedOver, 0);
      expect(budget.limit, 100000);
    });

    test('a month without the budget breaks the chain', () async {
      await rolloverOn();
      await repo.setBudget(month: august, amount: 100000);
      // September has no budget at all.
      await repo.setBudget(month: october, amount: 100000);

      final budget = (await repo.overallBudget(october))!;

      expect(budget.carriedOver, 0);
    });

    test('a category carries its own leftover only', () async {
      await rolloverOn();
      await repo.setBudget(month: september, amount: 50000, categoryId: food);
      await repo.setBudget(
        month: september,
        amount: 50000,
        categoryId: transport,
      );
      await repo.setBudget(month: october, amount: 50000, categoryId: food);
      await repo.setBudget(
        month: october,
        amount: 50000,
        categoryId: transport,
      );
      await spend(food, 20000, DateTime(2026, 9, 10));
      await spend(transport, 50000, DateTime(2026, 9, 11));

      final budget = await month(october);
      final byName = {for (final c in budget.categories) c.categoryName: c};

      expect(byName['Food']!.carriedOver, 30000);
      expect(byName['Food']!.limit, 80000);
      expect(byName['Transport']!.carriedOver, 0);
      expect(byName['Transport']!.limit, 50000);
    });

    test('only the last $rolloverMonths months count', () async {
      await rolloverOn();
      // A budget in each of 15 months, nothing spent: every month leaves all
      // of its limit. November gets what the 12 months before it left, not
      // the three older ones.
      for (var i = 0; i < 15; i++) {
        await repo.setBudget(month: DateTime(2025, 9 + i), amount: 100000);
      }

      final budget = (await repo.overallBudget(november))!;

      expect(budget.carriedOver, rolloverMonths * 100000);
    });

    test(
      'a budget set to carry nothing takes nothing and passes nothing on',
      () async {
        await rolloverOn();
        // September leaves 40,000, but October opts out.
        await repo.setBudget(month: september, amount: 100000);
        await repo.setBudget(month: october, amount: 100000, noCarry: true);
        await repo.setBudget(month: november, amount: 100000);
        await spend(food, 60000, DateTime(2026, 9, 10));

        final inOctober = (await repo.overallBudget(october))!;
        final inNovember = (await repo.overallBudget(november))!;

        expect(inOctober.noCarry, isTrue);
        expect(inOctober.carriedOver, 0);
        expect(inOctober.limit, 100000);
        // October passes nothing on, and it is all unspent.
        expect(inNovember.carriedOver, 0);
      },
    );

    test(
      'the flag is kept when the amount is changed, and can be changed',
      () async {
        await repo.setBudget(month: october, amount: 100000, noCarry: true);
        await repo.setBudget(month: october, amount: 120000);
        expect((await repo.overallBudget(october))!.noCarry, isTrue);

        await repo.setBudget(month: october, amount: 120000, noCarry: false);
        expect((await repo.overallBudget(october))!.noCarry, isFalse);
      },
    );

    test('copying last month keeps the flag', () async {
      await repo.setBudget(month: september, amount: 100000, noCarry: true);
      await repo.setBudget(month: september, amount: 50000, categoryId: food);

      await repo.copyFromPreviousMonth(october);

      final budget = await month(october);
      expect(budget.overall!.noCarry, isTrue);
      expect(budget.categories.single.noCarry, isFalse);
    });

    test('the set amount is the whole limit when nothing is carried', () async {
      await rolloverOn();
      await repo.setBudget(month: october, amount: 100000);

      final budget = (await repo.overallBudget(october))!;

      expect(budget.setAmount, budget.limit);
    });
  });

  group('what was left last month', () {
    test('is the overall budget less the spending', () async {
      await repo.setBudget(month: september, amount: 100000);
      await spend(food, 35000, DateTime(2026, 9, 10));

      expect(await repo.leftoverLastMonth(october), 65000);
    });

    test('is zero when it was all spent, overspent or never set', () async {
      expect(await repo.leftoverLastMonth(october), 0);

      await repo.setBudget(month: september, amount: 100000);
      await spend(food, 100000, DateTime(2026, 9, 10));
      expect(await repo.leftoverLastMonth(october), 0);

      await spend(food, 5000, DateTime(2026, 9, 11));
      expect(await repo.leftoverLastMonth(october), 0);
    });

    test('is the same whether carrying over is on or off', () async {
      await repo.setBudget(month: september, amount: 100000);
      final off = await repo.leftoverLastMonth(october);
      await db.settingsDao.put(PreferenceKeys.budgetRollover, 'true');

      expect(await repo.leftoverLastMonth(october), off);
    });
  });
}
