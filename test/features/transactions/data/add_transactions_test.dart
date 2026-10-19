import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;
  late int cash;
  late int bkash;
  late int food;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = TransactionsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  TransactionInput expense({int amount = 10000, int? account, int? category}) =>
      TransactionInput(
        type: TransactionType.expense,
        amount: amount,
        accountId: account ?? cash,
        categoryId: category ?? food,
        date: _now,
      );

  Future<List<TransactionRow>> saved() =>
      db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

  group('addTransactions', () {
    test('saves every row, of any mix of types and accounts', () async {
      final results = await repo.addTransactions([
        expense(),
        expense(amount: 2500, account: bkash),
        TransactionInput(
          type: TransactionType.income,
          amount: 300000,
          accountId: cash,
          categoryId: salary,
          date: _now,
        ),
        TransactionInput(
          type: TransactionType.transfer,
          amount: 50000,
          accountId: cash,
          toAccountId: bkash,
          date: _now,
        ),
      ]);

      expect(results, [null, null, null, null]);
      expect(await saved(), hasLength(4));
    });

    test('saves the same row twice when it is given twice', () async {
      // Two rows alike are two transactions: nothing here guesses duplicates.
      final results = await repo.addTransactions([expense(), expense()]);
      expect(results, [null, null]);
      expect(await saved(), hasLength(2));
    });

    test('keeps going after a row that fails, and says which failed', () async {
      final results = await repo.addTransactions([
        expense(amount: 100),
        // An income category on an expense.
        expense(amount: 200, category: salary),
        expense(amount: 300),
      ]);

      expect(results[0], isNull);
      expect(results[1], isNotNull);
      expect(results[1], contains('Salary'));
      expect(results[2], isNull);
      final rows = await saved();
      expect(rows.map((r) => r.amount), unorderedEquals([100, 300]));
    });

    test('does not undo the rows saved before a failing one', () async {
      final results = await repo.addTransactions([
        expense(amount: 100),
        expense(amount: 0),
      ]);

      expect(results[0], isNull);
      expect(results[1], isNotNull);
      expect(await saved(), hasLength(1));
    });

    test('with no rows saves nothing', () async {
      expect(await repo.addTransactions(const []), isEmpty);
      expect(await saved(), isEmpty);
    });
  });
}
