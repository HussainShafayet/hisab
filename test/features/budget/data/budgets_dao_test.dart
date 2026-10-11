import 'package:drift/drift.dart' show InvalidDataException, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';

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
}
