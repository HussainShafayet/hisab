import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

// Sunday 11 October 2026.
final today = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late RecurringRepository repo;
  late int cash;
  late int bkash;
  late int rent;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = RecurringRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    rent = await insertTestCategory(db, name: 'Rent');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<int> makeRent({
    DateTime? start,
    DateTime? end,
    bool auto = false,
    int amount = 1500000,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  }) => repo.createRule(
    title: 'House rent',
    type: TransactionType.expense,
    amount: amount,
    accountId: cash,
    categoryId: rent,
    frequency: frequency,
    startDate: start ?? DateTime(2026, 10, 5),
    endDate: end,
    autoAdd: auto,
  );

  Future<List<TransactionRow>> transactions() =>
      db.transactionsDao.getBetween(DateTime(2000), DateTime(2100));

  group('making a rule', () {
    test('saves it, due on the first day', () async {
      final id = await makeRent(start: DateTime(2026, 11, 5, 15));

      final rule = (await repo.getRule(id))!;

      expect(rule.title, 'House rent');
      expect(rule.type, TransactionType.expense);
      expect(rule.amount, 1500000);
      expect(rule.accountId, cash);
      expect(rule.categoryId, rent);
      expect(rule.frequency, RecurrenceFrequency.monthly);
      // Only the day counts.
      expect(rule.startDate, DateTime(2026, 11, 5));
      expect(rule.nextDue, DateTime(2026, 11, 5));
      expect(rule.endDate, isNull);
      expect(rule.autoAdd, isFalse);
      expect(rule.remind, isTrue);
      expect(rule.isPaused, isFalse);
    });

    test('trims the title and rejects a blank or long one', () async {
      final id = await repo.createRule(
        title: '  Rent  ',
        type: TransactionType.expense,
        amount: 100,
        accountId: cash,
        categoryId: rent,
        frequency: RecurrenceFrequency.weekly,
        startDate: DateTime(2026, 10, 5),
      );
      expect((await repo.getRule(id))!.title, 'Rent');

      Future<int> withTitle(String title) => repo.createRule(
        title: title,
        type: TransactionType.expense,
        amount: 100,
        accountId: cash,
        categoryId: rent,
        frequency: RecurrenceFrequency.weekly,
        startDate: DateTime(2026, 10, 5),
      );
      expect(() => withTitle('  '), throwsValidation('Name is required'));
      expect(() => withTitle('x' * 61), throwsValidation('60 characters'));
    });

    test('needs an amount above zero', () async {
      expect(() => makeRent(amount: 0), throwsValidation('above zero'));
    });

    test('cannot be a transfer', () async {
      expect(
        () => repo.createRule(
          title: 'Move',
          type: TransactionType.transfer,
          amount: 100,
          accountId: cash,
          categoryId: rent,
          frequency: RecurrenceFrequency.weekly,
          startDate: DateTime(2026, 10, 5),
        ),
        throwsValidation('income or an expense'),
      );
    });

    test('cannot end before it starts', () async {
      expect(
        () =>
            makeRent(start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 4)),
        throwsValidation('end day'),
      );
    });

    test('needs a category of the same type', () async {
      expect(
        () => repo.createRule(
          title: 'Pay',
          type: TransactionType.income,
          amount: 100,
          accountId: cash,
          categoryId: rent,
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2026, 10, 5),
        ),
        throwsValidation('not an income category'),
      );
    });

    test(
      'rejects an archived account or category, and a missing one',
      () async {
        await db.accountsDao.setArchived(bkash, archived: true);
        expect(
          () => repo.createRule(
            title: 'A',
            type: TransactionType.expense,
            amount: 1,
            accountId: bkash,
            categoryId: rent,
            frequency: RecurrenceFrequency.weekly,
            startDate: today,
          ),
          throwsValidation('archived'),
        );
        expect(
          () => repo.createRule(
            title: 'A',
            type: TransactionType.expense,
            amount: 1,
            accountId: 999,
            categoryId: rent,
            frequency: RecurrenceFrequency.weekly,
            startDate: today,
          ),
          throwsValidation('Account not found'),
        );
        expect(
          () => repo.createRule(
            title: 'A',
            type: TransactionType.expense,
            amount: 1,
            accountId: cash,
            categoryId: 999,
            frequency: RecurrenceFrequency.weekly,
            startDate: today,
          ),
          throwsValidation('Category not found'),
        );
      },
    );
  });

  group('changing a rule', () {
    Future<void> update(
      int id, {
      String title = 'House rent',
      int amount = 1500000,
      RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
      DateTime? start,
      bool auto = false,
    }) => repo.updateRule(
      id,
      title: title,
      type: TransactionType.expense,
      amount: amount,
      accountId: cash,
      categoryId: rent,
      frequency: frequency,
      startDate: start ?? DateTime(2026, 10, 5),
      autoAdd: auto,
      remind: true,
    );

    test('carries on from the day it was waiting for', () async {
      final id = await makeRent();
      await repo.skipDue(id, today);
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 11, 5));

      await update(id, title: 'Flat rent', amount: 1600000);

      final rule = (await repo.getRule(id))!;
      expect(rule.title, 'Flat rent');
      expect(rule.amount, 1600000);
      expect(rule.nextDue, DateTime(2026, 11, 5));
    });

    test('starts again from the new first day when the day or the frequency change', () async {
      final id = await makeRent();
      await repo.skipDue(id, today);

      await update(id, start: DateTime(2026, 12, 20));
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 12, 20));

      await update(
        id,
        start: DateTime(2026, 12, 20),
        frequency: RecurrenceFrequency.weekly,
      );
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 12, 20));
    });

    test('is checked like a new one, and needs a rule that exists', () async {
      final id = await makeRent();

      expect(() => update(id, amount: 0), throwsValidation('above zero'));
      expect(() => update(999), throwsValidation('not found'));
    });

    test('can keep an account that was archived since', () async {
      final id = await makeRent();
      await db.accountsDao.setArchived(cash, archived: true);

      await update(id, title: 'Renamed');

      expect((await repo.getRule(id))!.title, 'Renamed');
    });
  });

  group('pausing and deleting', () {
    test('a paused rule can be resumed', () async {
      final id = await makeRent();

      await repo.setPaused(id, paused: true);
      expect((await repo.getRule(id))!.isPaused, isTrue);
      await repo.setPaused(id, paused: false);
      expect((await repo.getRule(id))!.isPaused, isFalse);
    });

    test(
      'deleting removes the rule and keeps the transactions it made',
      () async {
        final id = await makeRent();
        await repo.addDue(id, today);

        await repo.deleteRule(id);

        expect(await repo.getRule(id), isNull);
        expect(await transactions(), hasLength(1));
        expect(() => repo.deleteRule(id), throwsValidation('not found'));
      },
    );
  });

  group('adding what is due', () {
    test('makes the transaction for the oldest due day and moves on', () async {
      final id = await makeRent(start: DateTime(2026, 8, 5));

      await repo.addDue(id, today);

      final row = (await transactions()).single;
      expect(row.type, TransactionType.expense);
      expect(row.amount, 1500000);
      expect(row.accountId, cash);
      expect(row.categoryId, rent);
      expect(row.note, 'House rent');
      expect(row.isAdjustment, isFalse);
      expect(
        DateTime(row.date.year, row.date.month, row.date.day),
        DateTime(2026, 8, 5),
      );
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 9, 5));
    });

    test('can add a different amount this time', () async {
      final id = await makeRent();

      await repo.addDue(id, today, amount: 1234500);

      expect((await transactions()).single.amount, 1234500);
      // The rule keeps its usual amount.
      expect((await repo.getRule(id))!.amount, 1500000);
    });

    test('works through the missed days one at a time', () async {
      final id = await makeRent(start: DateTime(2026, 8, 5));

      await repo.addDue(id, today);
      await repo.addDue(id, today);
      await repo.addDue(id, today);

      expect(await transactions(), hasLength(3));
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 11, 5));
      expect(() => repo.addDue(id, today), throwsValidation('Nothing is due'));
    });

    test('adds an income for an income rule', () async {
      final id = await repo.createRule(
        title: 'Salary',
        type: TransactionType.income,
        amount: 5000000,
        accountId: bkash,
        categoryId: salary,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 10, 1),
      );

      await repo.addDue(id, today);

      final row = (await transactions()).single;
      expect(row.type, TransactionType.income);
      expect(row.accountId, bkash);
    });

    test(
      'is refused before the day, for a paused rule, and past the end',
      () async {
        final future = await makeRent(start: DateTime(2026, 11, 5));
        expect(
          () => repo.addDue(future, today),
          throwsValidation('Nothing is due'),
        );

        final paused = await makeRent();
        await repo.setPaused(paused, paused: true);
        expect(() => repo.addDue(paused, today), throwsValidation('paused'));

        final ended = await makeRent(
          start: DateTime(2026, 9, 5),
          end: DateTime(2026, 9, 30),
        );
        await repo.addDue(ended, today);
        expect(
          () => repo.addDue(ended, today),
          throwsValidation('Nothing is due'),
        );
      },
    );

    test('changes nothing when the transaction cannot be saved', () async {
      final id = await makeRent();
      await db.accountsDao.setArchived(cash, archived: true);

      await expectLater(repo.addDue(id, today), throwsA(anything));

      expect(await transactions(), isEmpty);
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 10, 5));
    });
  });

  group('skipping', () {
    test('moves on without a transaction', () async {
      final id = await makeRent();

      await repo.skipDue(id, today);

      expect(await transactions(), isEmpty);
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 11, 5));
    });

    test('is refused when nothing is due', () async {
      final id = await makeRent(start: DateTime(2026, 11, 5));

      expect(() => repo.skipDue(id, today), throwsValidation('Nothing is due'));
    });
  });

  group('adding by itself', () {
    test('catches up on every missed day, once', () async {
      final id = await makeRent(start: DateTime(2026, 8, 5), auto: true);

      final added = await repo.addAutomatic(today);

      expect(added, 3);
      expect(await transactions(), hasLength(3));
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 11, 5));
      // A second run finds nothing more.
      expect(await repo.addAutomatic(today), 0);
      expect(await transactions(), hasLength(3));
    });

    test('leaves rules that ask first, and paused ones, alone', () async {
      await makeRent(start: DateTime(2026, 8, 5));
      final paused = await makeRent(start: DateTime(2026, 8, 5), auto: true);
      await repo.setPaused(paused, paused: true);

      expect(await repo.addAutomatic(today), 0);
      expect(await transactions(), isEmpty);
    });

    test('adds nothing before the day', () async {
      await makeRent(start: DateTime(2026, 11, 5), auto: true);

      expect(await repo.addAutomatic(today), 0);
    });

    test('stops at the end day', () async {
      final id = await makeRent(
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 9, 10),
        auto: true,
      );

      expect(await repo.addAutomatic(today), 2);
      expect((await repo.getRule(id))!.isFinished, isTrue);
    });

    test('leaves a rule waiting when its account was archived', () async {
      final id = await makeRent(start: DateTime(2026, 8, 5), auto: true);
      await db.accountsDao.setArchived(cash, archived: true);

      expect(await repo.addAutomatic(today), 0);

      expect(await transactions(), isEmpty);
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 8, 5));
    });

    test('keeps the 31st of the month through short months', () async {
      final id = await makeRent(
        start: DateTime(2026, 1, 31),
        auto: true,
        frequency: RecurrenceFrequency.monthly,
      );

      await repo.addAutomatic(DateTime(2026, 4, 30));

      final days = (await transactions()).map((t) => t.date.day).toList()
        ..sort();
      expect(days, [28, 30, 31, 31]);
      expect((await repo.getRule(id))!.nextDue, DateTime(2026, 5, 31));
    });
  });

  test('watchRules emits again after a change', () async {
    final seen = <int>[];
    final subscription = repo.watchRules().listen(
      (rules) => seen.add(rules.length),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await makeRent();
    await pumpEventQueue();

    expect(seen.first, 0);
    expect(seen.last, 1);
  });
}
