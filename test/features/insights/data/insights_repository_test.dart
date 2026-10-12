import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/insights/data/insights_repository.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

// Sunday 11 October 2026.
final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late InsightsRepository repo;
  late int cash;
  late int food;
  late int rent;

  setUp(() async {
    db = createTestDatabase();
    repo = InsightsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
    rent = await insertTestCategory(db, name: 'Rent');
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

  Future<List<InsightKind>> kinds() async => [
    for (final i in await repo.load(now)) i.kind,
  ];

  test('has nothing to say for an empty app', () async {
    expect(await repo.load(now), isEmpty);
  });

  test('compares this month so far with the same days of last month', () async {
    await spend(food, 150000, DateTime(2026, 10, 5));
    // Last month, up to the 11th: counted. After it: not.
    await spend(food, 100000, DateTime(2026, 9, 8));
    await spend(food, 900000, DateTime(2026, 9, 20));

    final up = (await repo.load(now))
        .firstWhere((i) => i.kind == InsightKind.spendingUp);

    expect(up.args['percent'], 50);
  });

  test('does not count what is spent after today', () async {
    await spend(food, 100000, DateTime(2026, 10, 5));
    await spend(food, 900000, DateTime(2026, 10, 20));
    await spend(food, 100000, DateTime(2026, 9, 8));

    // 100,000 against 100,000: no change.
    expect(await kinds(), isNot(contains(InsightKind.spendingUp)));
  });

  test('compares with the end of a shorter last month', () async {
    // On 31 October, last month had 30 days: the whole of September counts.
    await spend(food, 100000, DateTime(2026, 9, 30));
    await spend(food, 200000, DateTime(2026, 10, 3));

    final list = await repo.load(DateTime(2026, 10, 31));

    expect(
      list.firstWhere((i) => i.kind == InsightKind.spendingUp).args['percent'],
      100,
    );
  });

  test('works out the pace of the overall budget', () async {
    await BudgetsRepository(db)
        .setBudget(month: DateTime(2026, 10), amount: 100000);
    await spend(food, 40000, DateTime(2026, 10, 4));

    final over = (await repo.load(now))
        .firstWhere((i) => i.kind == InsightKind.overBudgetPace);

    expect(over.args['limit'], 100000);
    expect(over.args['projected'], 112727);
  });

  test('mentions the next recurring item that is coming up', () async {
    final repository = RecurringRepository(db);
    Future<void> make(String title, DateTime start) => repository
        .createRule(
          title: title,
          type: TransactionType.expense,
          amount: 1000,
          accountId: cash,
          categoryId: rent,
          frequency: RecurrenceFrequency.monthly,
          startDate: start,
        )
        .then((_) {});
    await make('Far', DateTime(2026, 11, 20));
    await make('Soon', DateTime(2026, 10, 14));
    await make('Past', DateTime(2026, 10, 5));

    final soon = (await repo.load(now))
        .firstWhere((i) => i.kind == InsightKind.recurringSoon);

    expect(soon.args['title'], 'Soon');
    expect(soon.args['days'], 3);
  });

  test('a paused recurring item is not mentioned', () async {
    final repository = RecurringRepository(db);
    final id = await repository.createRule(
      title: 'Soon',
      type: TransactionType.expense,
      amount: 1000,
      accountId: cash,
      categoryId: rent,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 10, 14),
    );
    await repository.setPaused(id, paused: true);

    expect(await kinds(), isEmpty);
  });
}
