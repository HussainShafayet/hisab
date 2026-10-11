import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late int cash;
  late int bkash;
  late int food;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(db, name: 'Salary');
  });
  tearDown(() => db.close());

  TransactionsCompanion expense({
    int amount = 25000,
    DateTime? date,
    String note = '',
    int? accountId,
  }) => TransactionsCompanion.insert(
    type: TransactionType.expense,
    amount: amount,
    accountId: accountId ?? cash,
    categoryId: Value(food),
    date: date ?? DateTime(2026, 10, 11, 12),
    note: Value(note),
  );

  TransactionsCompanion transfer({
    int? from,
    int? to,
    int? categoryId,
    int amount = 100000,
  }) => TransactionsCompanion.insert(
    type: TransactionType.transfer,
    amount: amount,
    accountId: from ?? cash,
    toAccountId: Value(to ?? bkash),
    categoryId: Value(categoryId),
    date: DateTime(2026, 10, 11),
  );

  group('storing', () {
    test('round-trips an expense, with defaults', () async {
      final id = await db.transactionsDao.insertTransaction(
        expense(amount: 123456, note: 'Lunch'),
      );

      final row = (await db.transactionsDao.getById(id))!;

      expect(row.type, TransactionType.expense);
      expect(row.amount, 123456);
      expect(row.accountId, cash);
      expect(row.toAccountId, isNull);
      expect(row.categoryId, food);
      expect(row.note, 'Lunch');
      expect(row.date, DateTime(2026, 10, 11, 12));
      expect(row.createdAt.difference(DateTime.now()).inMinutes.abs(), 0);
    });

    test('note defaults to an empty string', () async {
      final id = await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.income,
          amount: 5000000,
          accountId: bkash,
          categoryId: Value(salary),
          date: DateTime(2026, 10, 1),
        ),
      );

      expect((await db.transactionsDao.getById(id))!.note, '');
    });

    test('stores the date as a UTC unix timestamp', () async {
      final moment = DateTime.utc(2026, 1, 31, 18, 30);
      final id = await db.transactionsDao.insertTransaction(
        expense(date: moment),
      );

      final raw = await db
          .customSelect(
            'SELECT date FROM transactions WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();
      final read = (await db.transactionsDao.getById(id))!.date;

      expect(raw.read<int>('date'), moment.millisecondsSinceEpoch ~/ 1000);
      expect(read.isAtSameMomentAs(moment), isTrue);
    });

    test('keeps amounts as exact integers', () async {
      const large = 9007199254740000; // beyond what a double adds exactly
      final id = await db.transactionsDao.insertTransaction(
        expense(amount: large),
      );

      expect((await db.transactionsDao.getById(id))!.amount, large);
    });

    test('accepts a transfer between two accounts', () async {
      final id = await db.transactionsDao.insertTransaction(transfer());

      final row = (await db.transactionsDao.getById(id))!;

      expect(row.type, TransactionType.transfer);
      expect(row.accountId, cash);
      expect(row.toAccountId, bkash);
      expect(row.categoryId, isNull);
    });
  });

  group('rejecting invalid rows', () {
    test('zero or negative amount', () async {
      expect(
        () => db.transactionsDao.insertTransaction(expense(amount: 0)),
        throwsConstraint('CHECK'),
      );
      expect(
        () => db.transactionsDao.insertTransaction(expense(amount: -100)),
        throwsConstraint('CHECK'),
      );
    });

    test('income or expense without a category', () async {
      expect(
        () => db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 100,
            accountId: cash,
            date: DateTime(2026, 10, 11),
          ),
        ),
        throwsConstraint('CHECK'),
      );
    });

    test('income or expense with a destination account', () async {
      expect(
        () => db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 100,
            accountId: cash,
            toAccountId: Value(bkash),
            categoryId: Value(food),
            date: DateTime(2026, 10, 11),
          ),
        ),
        throwsConstraint('CHECK'),
      );
    });

    test('transfer without a destination account', () async {
      expect(
        () => db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.transfer,
            amount: 100,
            accountId: cash,
            date: DateTime(2026, 10, 11),
          ),
        ),
        throwsConstraint('CHECK'),
      );
    });

    test('transfer to the same account', () async {
      expect(
        () => db.transactionsDao.insertTransaction(
          transfer(from: cash, to: cash),
        ),
        throwsConstraint('CHECK'),
      );
    });

    test('transfer with a category', () async {
      expect(
        () => db.transactionsDao.insertTransaction(transfer(categoryId: food)),
        throwsConstraint('CHECK'),
      );
    });

    test('unknown account or category', () async {
      expect(
        () => db.transactionsDao.insertTransaction(expense(accountId: 999)),
        throwsConstraint('FOREIGN KEY'),
      );
      expect(
        () => db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 100,
            accountId: cash,
            categoryId: const Value(999),
            date: DateTime(2026, 10, 11),
          ),
        ),
        throwsConstraint('FOREIGN KEY'),
      );
    });
  });

  group('accounts and categories are archived, never deleted', () {
    test('an account with transactions cannot be hard deleted', () async {
      await db.transactionsDao.insertTransaction(expense());
      await db.transactionsDao.insertTransaction(
        transfer(from: bkash, to: cash),
      );

      expect(
        () => (db.delete(db.accounts)..where((a) => a.id.equals(cash))).go(),
        throwsConstraint('FOREIGN KEY'),
      );
      expect(
        () => (db.delete(db.accounts)..where((a) => a.id.equals(bkash))).go(),
        throwsConstraint('FOREIGN KEY'),
      );
    });

    test('a category with transactions cannot be hard deleted', () async {
      await db.transactionsDao.insertTransaction(expense());

      expect(
        () => (db.delete(db.categories)..where((c) => c.id.equals(food))).go(),
        throwsConstraint('FOREIGN KEY'),
      );
    });

    test('archiving leaves old transactions intact', () async {
      final id = await db.transactionsDao.insertTransaction(expense());

      await db.accountsDao.setArchived(cash, archived: true);
      await db.categoriesDao.setArchived(food, archived: true);

      final row = (await db.transactionsDao.getById(id))!;
      expect(row.accountId, cash);
      expect(row.categoryId, food);
      expect(await db.accountsDao.getById(cash), isNotNull);
      expect(await db.categoriesDao.getById(food), isNotNull);
    });
  });

  group('updating and deleting', () {
    test('update replaces the row and refreshes updatedAt only', () async {
      final id = await db.transactionsDao.insertTransaction(expense());
      final original = (await db.transactionsDao.getById(id))!;

      final updated = await db.transactionsDao.updateTransaction(
        original.copyWith(amount: 99900, note: 'Dinner'),
      );

      expect(updated, isTrue);
      final row = (await db.transactionsDao.getById(id))!;
      expect(row.amount, 99900);
      expect(row.note, 'Dinner');
      expect(row.createdAt, original.createdAt);
      expect(row.updatedAt.isBefore(original.updatedAt), isFalse);
    });

    test('update of a missing id returns false', () async {
      final id = await db.transactionsDao.insertTransaction(expense());
      final row = (await db.transactionsDao.getById(id))!;
      await db.transactionsDao.deleteTransaction(id);

      expect(await db.transactionsDao.updateTransaction(row), isFalse);
    });

    test('delete can be undone by inserting the same row again', () async {
      final id = await db.transactionsDao.insertTransaction(
        expense(note: 'Taxi'),
      );
      final deleted = (await db.transactionsDao.getById(id))!;

      expect(await db.transactionsDao.deleteTransaction(id), 1);
      expect(await db.transactionsDao.getById(id), isNull);

      await db.transactionsDao.insertTransaction(deleted.toCompanion(true));

      expect(await db.transactionsDao.getById(id), deleted);
    });
  });

  group('querying a date range', () {
    Future<List<int>> idsBetween(DateTime start, DateTime end) async =>
        (await db.transactionsDao.getBetween(
          start,
          end,
        )).map((t) => t.id).toList();

    test('includes the start and excludes the end', () async {
      final start = DateTime(2026, 10);
      final end = DateTime(2026, 11);
      final before = await db.transactionsDao.insertTransaction(
        expense(date: DateTime(2026, 9, 30, 23, 59, 59)),
      );
      final atStart = await db.transactionsDao.insertTransaction(
        expense(date: start),
      );
      final lastMoment = await db.transactionsDao.insertTransaction(
        expense(date: DateTime(2026, 10, 31, 23, 59, 59)),
      );
      final atEnd = await db.transactionsDao.insertTransaction(
        expense(date: end),
      );

      final ids = await idsBetween(start, end);

      expect(ids, containsAll([atStart, lastMoment]));
      expect(ids, isNot(contains(before)));
      expect(ids, isNot(contains(atEnd)));
    });

    test('orders newest first, breaking ties by newest id', () async {
      final sameDay = DateTime(2026, 10, 5, 9);
      final older = await db.transactionsDao.insertTransaction(
        expense(date: DateTime(2026, 10, 2)),
      );
      final first = await db.transactionsDao.insertTransaction(
        expense(date: sameDay),
      );
      final second = await db.transactionsDao.insertTransaction(
        expense(date: sameDay),
      );
      final newest = await db.transactionsDao.insertTransaction(
        expense(date: DateTime(2026, 10, 9)),
      );

      final ids = await idsBetween(DateTime(2026, 10), DateTime(2026, 11));

      expect(ids, [newest, second, first, older]);
    });

    test('watchBetween emits again when a transaction is added', () async {
      final emissions = <int>[];
      final subscription = db.transactionsDao
          .watchBetween(DateTime(2026, 10), DateTime(2026, 11))
          .listen((rows) => emissions.add(rows.length));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await db.transactionsDao.insertTransaction(expense());
      await pumpEventQueue();
      await db.transactionsDao.insertTransaction(
        expense(date: DateTime(2026, 12)),
      );
      await pumpEventQueue();

      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });
}
