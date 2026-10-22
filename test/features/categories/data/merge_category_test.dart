import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/challenges/data/challenges_repository.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository repo;
  late Basics b;
  late int rickshaw;
  late int bus;

  setUp(() async {
    db = createTestDatabase();
    repo = CategoriesRepository(db);
    b = await seedBasics(db);
    // "Rickshaw" and "Bus" are two names for the same spending.
    rickshaw = await insertTestCategory(db, name: 'Rickshaw');
    bus = await insertTestCategory(db, name: 'Bus & rickshaw');
  });
  tearDown(() => db.close());

  Future<int> spend(int category, int amount) => addTransaction(
    db,
    type: TransactionType.expense,
    amount: amount,
    accountId: b.cash,
    categoryId: category,
    date: DateTime(2026, 10, 5, 12),
  );

  Future<CategoryRow> category(int id) async =>
      (await db.categoriesDao.getAll(includeArchived: true))
          .firstWhere((c) => c.id == id);

  group('merging a category into another', () {
    test('moves its transactions and archives it', () async {
      final a = await spend(rickshaw, 4000);
      final c = await spend(rickshaw, 3000);
      final d = await spend(bus, 2000);

      final result = await repo.mergeCategory(rickshaw, intoId: bus);

      expect(result.transactions, 2);
      for (final id in [a, c, d]) {
        expect((await db.transactionsDao.getById(id))!.categoryId, bus);
      }
      expect((await category(rickshaw)).isArchived, isTrue);
      expect((await category(bus)).isArchived, isFalse);
    });

    test('a category nothing uses merges too', () async {
      final result = await repo.mergeCategory(rickshaw, intoId: bus);

      expect(result.transactions, 0);
      expect((await category(rickshaw)).isArchived, isTrue);
    });

    test('a budget moves over, or adds to the one of the same month', () async {
      final budgets = BudgetsRepository(db);
      await budgets.setBudget(
        month: DateTime(2026, 10),
        categoryId: rickshaw,
        amount: 100000,
      );
      await budgets.setBudget(
        month: DateTime(2026, 11),
        categoryId: rickshaw,
        amount: 50000,
      );
      await budgets.setBudget(
        month: DateTime(2026, 10),
        categoryId: bus,
        amount: 200000,
      );

      final result = await repo.mergeCategory(rickshaw, intoId: bus);

      expect(result.budgets, 2);
      final rows = await db.select(db.budgets).get();
      expect(rows.where((r) => r.categoryId == rickshaw), isEmpty);
      final october = rows.singleWhere(
        (r) => r.categoryId == bus && r.month == '2026-10',
      );
      expect(october.amount, 300000);
      final november = rows.singleWhere(
        (r) => r.categoryId == bus && r.month == '2026-11',
      );
      expect(november.amount, 50000);
    });

    test('repeating entries and challenges move too', () async {
      await db
          .into(db.recurringRules)
          .insert(
            RecurringRulesCompanion.insert(
              title: 'Daily bus',
              type: TransactionType.expense,
              amount: 6000,
              accountId: b.cash,
              categoryId: rickshaw,
              frequency: RecurrenceFrequency.weekly,
              startDate: DateTime(2026, 10, 1),
              nextDue: DateTime(2026, 10, 12),
            ),
          );
      await ChallengesRepository(db).create(
        title: 'No rickshaw',
        kind: ChallengeKind.noSpend,
        startDate: DateTime(2026, 10, 12),
        endDate: DateTime(2026, 10, 18),
        categoryId: rickshaw,
      );

      final result = await repo.mergeCategory(rickshaw, intoId: bus);

      expect(result.rules, 1);
      expect(result.challenges, 1);
      expect((await db.select(db.recurringRules).get()).single.categoryId, bus);
      expect((await db.select(db.challenges).get()).single.categoryId, bus);
    });

    test(
      'a category inside another can be merged into one elsewhere',
      () async {
        final parent = await insertTestCategory(db, name: 'Transport trips');
        final inside = await insertTestCategory(
          db,
          name: 'Boat',
          parentId: parent,
        );
        await spend(inside, 1000);

        await repo.mergeCategory(inside, intoId: bus);

        expect((await db.transactionsDao.getAll()).single.categoryId, bus);
        expect((await category(inside)).isArchived, isTrue);
        expect((await category(parent)).isArchived, isFalse);
      },
    );

    test('all or nothing: nothing changes when it is refused', () async {
      final a = await spend(rickshaw, 4000);

      await expectLater(
        repo.mergeCategory(rickshaw, intoId: b.salary),
        throwsA(isA<ValidationException>()),
      );

      expect((await db.transactionsDao.getById(a))!.categoryId, rickshaw);
      expect((await category(rickshaw)).isArchived, isFalse);
    });
  });

  group('what cannot be merged', () {
    test('into itself', () async {
      await expectLater(
        repo.mergeCategory(rickshaw, intoId: rickshaw),
        throwsA(isA<ValidationException>()),
      );
    });

    test('into a category of the other type', () async {
      await expectLater(
        repo.mergeCategory(
          rickshaw,
          intoId: await insertTestCategory(
            db,
            name: 'Bonus',
            type: CategoryType.income,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('into an archived category', () async {
      await db.categoriesDao.setArchived(bus, archived: true);

      await expectLater(
        repo.mergeCategory(rickshaw, intoId: bus),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a category with sub-categories in use', () async {
      await insertTestCategory(db, name: 'Boat', parentId: rickshaw);

      await expectLater(
        repo.mergeCategory(rickshaw, intoId: bus),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('has sub-categories'),
          ),
        ),
      );
    });

    test('a category whose sub-categories are all archived is fine', () async {
      final boat = await insertTestCategory(
        db,
        name: 'Boat',
        parentId: rickshaw,
      );
      await db.categoriesDao.setArchived(boat, archived: true);

      await repo.mergeCategory(rickshaw, intoId: bus);

      expect((await category(rickshaw)).isArchived, isTrue);
    });

    test('a category that is not there', () async {
      await expectLater(
        repo.mergeCategory(99999, intoId: bus),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repo.mergeCategory(rickshaw, intoId: 99999),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
