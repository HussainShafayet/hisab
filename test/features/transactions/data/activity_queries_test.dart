import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late int cash;
  late int bkash;
  late int food;

  setUp(() async {
    db = createTestDatabase();
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
  });
  tearDown(() => db.close());

  Future<int> add(
    TransactionType type,
    DateTime date, {
    int amount = 10000,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: cash,
      toAccountId: Value(type == TransactionType.transfer ? bkash : null),
      categoryId: Value(type == TransactionType.transfer ? null : food),
      date: date,
      isAdjustment: Value(adjustment),
    ),
  );

  group('activityDays', () {
    test('is empty when nothing was written', () async {
      expect(await db.activityDays(), isEmpty);
    });

    test('says whether an expense was written on each day', () async {
      // 3 Oct: an income and an expense. 5 Oct: income only.
      await add(TransactionType.income, DateTime(2026, 10, 3, 9));
      await add(TransactionType.expense, DateTime(2026, 10, 3, 20));
      await add(TransactionType.income, DateTime(2026, 10, 5, 12));

      expect(await db.activityDays(), {
        DateTime(2026, 10, 3): true,
        DateTime(2026, 10, 5): false,
      });
    });

    test(
      'counts a transfer as a day with an entry, but not as spending',
      () async {
        await add(TransactionType.transfer, DateTime(2026, 10, 6, 12));

        expect(await db.activityDays(), {DateTime(2026, 10, 6): false});
      },
    );

    test('leaves out balance adjustments', () async {
      await add(
        TransactionType.expense,
        DateTime(2026, 10, 7, 12),
        adjustment: true,
      );
      await add(TransactionType.income, DateTime(2026, 10, 8, 12));

      expect(await db.activityDays(), {DateTime(2026, 10, 8): false});
    });

    test('puts late evening on its own local day', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 9, 23, 30));
      await add(TransactionType.expense, DateTime(2026, 10, 10, 0, 15));

      final days = await db.activityDays();
      expect(days.keys.toSet(), {
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 10),
      });
    });
  });

  group('entryCount', () {
    test(
      'counts entries from the start up to, not including, the end',
      () async {
        await add(TransactionType.expense, DateTime(2026, 9, 30, 23, 59));
        await add(TransactionType.expense, DateTime(2026, 10, 1));
        await add(TransactionType.income, DateTime(2026, 10, 31, 23, 59));
        await add(TransactionType.expense, DateTime(2026, 11, 1));

        expect(await db.entryCount(DateTime(2026, 10), DateTime(2026, 11)), 2);
      },
    );

    test('leaves out balance adjustments', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 5, 12));
      await add(
        TransactionType.income,
        DateTime(2026, 10, 5, 13),
        adjustment: true,
      );

      expect(await db.entryCount(DateTime(2026, 10), DateTime(2026, 11)), 1);
    });

    test('is zero for an empty period', () async {
      expect(await db.entryCount(DateTime(2026, 10), DateTime(2026, 11)), 0);
    });
  });
}
