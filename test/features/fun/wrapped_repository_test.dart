import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/fun/data/wrapped_repository.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late WrappedRepository repo;
  late int cash;
  late int food;
  late int transport;
  late int pay;

  setUp(() async {
    db = createTestDatabase();
    repo = WrappedRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
    transport = await insertTestCategory(db, name: 'Transport');
    pay = await insertTestCategory(db, name: 'Pay', type: CategoryType.income);
  });
  tearDown(() => db.close());

  Future<void> add(
    TransactionType type,
    DateTime date,
    int amount,
    int category, {
    Feeling? feeling,
    bool adjustment = false,
  }) async {
    await db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: type,
        amount: amount,
        accountId: cash,
        categoryId: Value(category),
        date: date,
        feeling: Value(feeling),
        isAdjustment: Value(adjustment),
      ),
    );
  }

  group('load', () {
    test('is all zeros for a month with nothing in it', () async {
      final w = await repo.load(DateTime(2026, 10, 11), DateTime(2026, 10, 11));

      expect(w.month, DateTime(2026, 10));
      expect(w.income, 0);
      expect(w.expense, 0);
      expect(w.entries, 0);
      expect(w.spendFreeDays, 0);
      expect(w.topCategory, isNull);
      expect(w.topCategoryAmount, 0);
      expect(w.biggest, isNull);
      expect(w.feelings.total, 0);
    });

    test(
      'adds up the month: totals, top category, biggest, feelings',
      () async {
        await add(
          TransactionType.income,
          DateTime(2026, 10, 2, 9),
          5000000,
          pay,
        );
        await add(
          TransactionType.expense,
          DateTime(2026, 10, 3, 12),
          25000,
          food,
          feeling: Feeling.need,
        );
        await add(
          TransactionType.expense,
          DateTime(2026, 10, 3, 18),
          7000,
          transport,
          feeling: Feeling.regret,
        );
        await add(
          TransactionType.expense,
          DateTime(2026, 10, 8, 13),
          100000,
          food,
          feeling: Feeling.want,
        );
        // A balance fix is not part of the story.
        await add(
          TransactionType.expense,
          DateTime(2026, 10, 9, 10),
          999999,
          food,
          adjustment: true,
        );
        // Another month is left out.
        await add(TransactionType.expense, DateTime(2026, 9, 20), 50000, food);

        final w = await repo.load(
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 11),
        );

        expect(w.month, DateTime(2026, 10));
        expect(w.income, 5000000);
        expect(w.expense, 132000);
        expect(w.entries, 4);
        expect(w.topCategory, 'Food');
        expect(w.topCategoryAmount, 125000);
        expect(w.biggest!.amount, 100000);
        expect(w.feelings.need, 25000);
        expect(w.feelings.want, 100000);
        expect(w.feelings.regret, 7000);
      },
    );

    test('counts spend-free days up to yesterday in the current month', () async {
      await add(TransactionType.income, DateTime(2026, 10, 2, 9), 5000000, pay);
      await add(
        TransactionType.expense,
        DateTime(2026, 10, 3, 12),
        25000,
        food,
      );
      await add(
        TransactionType.expense,
        DateTime(2026, 10, 8, 13),
        100000,
        food,
      );

      // Today is 11 Oct: 2..10 Oct is nine days, and 3 and 8 Oct had spending.
      final w = await repo.load(DateTime(2026, 10, 11), DateTime(2026, 10, 11));

      expect(w.spendFreeDays, 7);
    });

    test(
      'counts every day to the month end for a month that is over',
      () async {
        await add(
          TransactionType.expense,
          DateTime(2026, 9, 10, 12),
          25000,
          food,
        );

        // 10..30 Sep is 21 days, and 10 Sep had spending.
        final w = await repo.load(
          DateTime(2026, 9, 15),
          DateTime(2026, 10, 11),
        );

        expect(w.spendFreeDays, 20);
      },
    );
  });
}
