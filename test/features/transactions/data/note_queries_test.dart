import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/data/note_queries.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late int cash;
  late int bkash;
  late int food;
  late int pay;

  setUp(() async {
    db = createTestDatabase();
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    pay = await insertTestCategory(db, name: 'Pay', type: CategoryType.income);
  });
  tearDown(() => db.close());

  Future<int> add(
    TransactionType type,
    DateTime date,
    String note, {
    int amount = 10000,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: cash,
      toAccountId: Value(type == TransactionType.transfer ? bkash : null),
      categoryId: Value(switch (type) {
        TransactionType.expense => food,
        TransactionType.income => pay,
        TransactionType.transfer => null,
      }),
      date: date,
      note: Value(note),
      isAdjustment: Value(adjustment),
    ),
  );

  group('pastNotes', () {
    test('is empty when no entry has a note', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 3), '');

      expect(await db.pastNotes(), isEmpty);
    });

    test('lists income and expense notes, newest first', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 3), 'Rickshaw');
      await add(
        TransactionType.income,
        DateTime(2026, 10, 4),
        'Bonus',
        amount: 500000,
      );

      final notes = await db.pastNotes();

      expect(notes.map((n) => n.note), ['Bonus', 'Rickshaw']);
      expect(notes.first.type, TransactionType.income);
      expect(notes.first.amount, 500000);
      expect(notes.first.categoryId, pay);
      expect(notes.last.type, TransactionType.expense);
      expect(notes.last.categoryId, food);
    });

    test('leaves out transfers and balance adjustments', () async {
      await add(TransactionType.transfer, DateTime(2026, 10, 5), 'Move');
      await add(
        TransactionType.expense,
        DateTime(2026, 10, 6),
        'Fix',
        adjustment: true,
      );
      await add(TransactionType.expense, DateTime(2026, 10, 7), 'Lunch');

      expect((await db.pastNotes()).map((n) => n.note), ['Lunch']);
    });

    test('puts the later entry first when two share a date', () async {
      final day = DateTime(2026, 10, 8, 12);
      await add(TransactionType.expense, day, 'First');
      await add(TransactionType.expense, day, 'Second');

      expect((await db.pastNotes()).map((n) => n.note), ['Second', 'First']);
    });

    test('stops at the limit, keeping the newest', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 1), 'Old');
      await add(TransactionType.expense, DateTime(2026, 10, 2), 'Middle');
      await add(TransactionType.expense, DateTime(2026, 10, 3), 'New');

      expect((await db.pastNotes(limit: 2)).map((n) => n.note), [
        'New',
        'Middle',
      ]);
    });
  });

  group('entryWithNote', () {
    test('finds an entry whose note holds the text', () async {
      final id = await add(
        TransactionType.expense,
        DateTime(2026, 10, 9),
        'bKash Cash Out TrxID ABC123 done',
      );

      final row = await db.entryWithNote('TrxID ABC123');

      expect(row, isNotNull);
      expect(row!.id, id);
    });

    test('is null when no note holds it', () async {
      await add(TransactionType.expense, DateTime(2026, 10, 9), 'Lunch');

      expect(await db.entryWithNote('TrxID ABC123'), isNull);
    });

    test('is null on an empty database', () async {
      expect(await db.entryWithNote('anything'), isNull);
    });
  });
}
