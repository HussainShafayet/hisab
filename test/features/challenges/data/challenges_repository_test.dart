import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/challenges/data/challenges_repository.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

// A week: Sunday 11 to Saturday 17 October 2026.
final start = DateTime(2026, 10, 11);
final end = DateTime(2026, 10, 17);

void main() {
  late AppDatabase db;
  late ChallengesRepository repo;
  late int cash;
  late int bank;
  late int transport;
  late int rickshaw;
  late int food;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    repo = ChallengesRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bank = await insertTestAccount(db, name: 'Bank');
    transport = await insertTestCategory(db, name: 'Transport');
    rickshaw = await insertTestCategory(
      db,
      name: 'Rickshaw',
      parentId: transport,
    );
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(
      db,
      name: 'Salary',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<void> add(
    int amount,
    DateTime date, {
    int? category,
    TransactionType type = TransactionType.expense,
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: cash,
      categoryId: Value(
        type == TransactionType.transfer ? null : (category ?? food),
      ),
      toAccountId: Value(type == TransactionType.transfer ? bank : null),
      date: date,
      isAdjustment: Value(adjustment),
    ),
  );

  Future<int> week({
    ChallengeKind kind = ChallengeKind.limit,
    int limit = 100000,
    int? category,
  }) => repo.create(
    title: 'A week',
    kind: kind,
    startDate: start,
    endDate: end,
    limit: limit,
    categoryId: category,
  );

  Future<ChallengeItem> read(int id) async => (await repo.getChallenge(id))!;

  group('making a challenge', () {
    test('keeps what was asked, with nothing spent yet', () async {
      final id = await repo.create(
        title: '  No rickshaw  ',
        kind: ChallengeKind.noSpend,
        startDate: DateTime(2026, 10, 11, 15, 30),
        endDate: DateTime(2026, 10, 17, 8),
        categoryId: rickshaw,
      );

      final item = await read(id);

      expect(item.challenge.title, 'No rickshaw');
      expect(item.challenge.kind, ChallengeKind.noSpend);
      expect(item.challenge.categoryId, rickshaw);
      expect(item.categoryName, 'Rickshaw');
      expect(item.challenge.startDate, start);
      expect(item.challenge.endDate, end);
      expect(item.challenge.limit, 0);
      expect(item.challenge.days, 7);
      expect(item.spent, 0);
    });

    test('a no-spend challenge has no limit even if one is given', () async {
      final id = await week(kind: ChallengeKind.noSpend, limit: 99999);

      expect((await read(id)).challenge.limit, 0);
    });

    test('a limit challenge keeps its limit', () async {
      final id = await week(limit: 250000);

      expect((await read(id)).challenge.limit, 250000);
    });
  });

  group('the rules', () {
    Future<void> expectRefused(Future<Object?> action) =>
        expectLater(action, throwsA(isA<ValidationException>()));

    test('a name is needed, and not too long', () async {
      await expectRefused(
        repo.create(
          title: '   ',
          kind: ChallengeKind.noSpend,
          startDate: start,
          endDate: end,
        ),
      );
      await expectRefused(
        repo.create(
          title: 'x' * (maxChallengeTitleLength + 1),
          kind: ChallengeKind.noSpend,
          startDate: start,
          endDate: end,
        ),
      );
    });

    test('the end cannot be before the start', () async {
      await expectRefused(
        repo.create(
          title: 'Backwards',
          kind: ChallengeKind.noSpend,
          startDate: end,
          endDate: start,
        ),
      );
    });

    test('one day is fine, more than a year is not', () async {
      await repo.create(
        title: 'A day',
        kind: ChallengeKind.noSpend,
        startDate: start,
        endDate: start,
      );
      await repo.create(
        title: 'A year',
        kind: ChallengeKind.noSpend,
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
      );
      await expectRefused(
        repo.create(
          title: 'Too long',
          kind: ChallengeKind.noSpend,
          startDate: DateTime(2026),
          endDate: DateTime(2027, 1, 2),
        ),
      );
    });

    test('a limit challenge needs a limit above zero', () async {
      await expectRefused(week(limit: 0));
      await expectRefused(week(limit: -5));
    });

    test(
      'the category must be an expense category that is not archived',
      () async {
        await expectRefused(week(category: 9999));
        await expectRefused(week(category: salary));
        await db.categoriesDao.setArchived(food, archived: true);
        await expectRefused(week(category: food));
      },
    );
  });

  group('what was spent', () {
    test('counts the expenses of its days, both ends included', () async {
      final id = await week();
      await add(1000, DateTime(2026, 10, 10, 23, 59)); // the day before
      await add(2000, DateTime(2026, 10, 11, 0, 0));
      await add(3000, DateTime(2026, 10, 14, 12));
      await add(4000, DateTime(2026, 10, 17, 23, 59));
      await add(5000, DateTime(2026, 10, 18, 0, 0)); // the day after

      expect((await read(id)).spent, 2000 + 3000 + 4000);
    });

    test('leaves out income, transfers and balance adjustments', () async {
      final id = await week();
      await add(1000, DateTime(2026, 10, 12), category: food);
      await add(
        900000,
        DateTime(2026, 10, 12),
        category: salary,
        type: TransactionType.income,
      );
      await add(70000, DateTime(2026, 10, 12), type: TransactionType.transfer);
      await add(30000, DateTime(2026, 10, 12), adjustment: true);

      expect((await read(id)).spent, 1000);
    });

    test('a category counts what is inside it too, and no other', () async {
      final id = await week(category: transport);
      await add(1000, DateTime(2026, 10, 12), category: transport);
      await add(2000, DateTime(2026, 10, 13), category: rickshaw);
      await add(4000, DateTime(2026, 10, 13), category: food);

      expect((await read(id)).spent, 3000);
    });

    test('a sub-category does not count its parent', () async {
      final id = await week(category: rickshaw);
      await add(1000, DateTime(2026, 10, 12), category: transport);
      await add(2000, DateTime(2026, 10, 13), category: rickshaw);

      expect((await read(id)).spent, 2000);
    });

    test(
      'the list shows the latest start first, each with its own spending',
      () async {
        final early = await repo.create(
          title: 'Early',
          kind: ChallengeKind.limit,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 7),
          limit: 50000,
        );
        final late = await week();
        await add(700, DateTime(2026, 9, 3));
        await add(900, DateTime(2026, 10, 12));

        final items = await repo.watchChallenges().first;

        expect(items.map((i) => i.challenge.id), [late, early]);
        expect(items.map((i) => i.spent), [900, 700]);
      },
    );

    test('the stream gives the new total when an expense is written', () async {
      final id = await week();
      final seen = <int>[];
      final sub = repo.watchChallenges().listen(
        (items) => seen.add(items.single.spent),
      );
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      await add(1500, DateTime(2026, 10, 12));
      await pumpEventQueue();

      expect(seen.first, 0);
      expect(seen.last, 1500);
      expect(id, isNonZero);
    });
  });

  group('changing and removing', () {
    test('update changes what was asked', () async {
      final id = await week();

      await repo.update(
        id,
        title: 'Now nothing',
        kind: ChallengeKind.noSpend,
        startDate: DateTime(2026, 10, 12),
        endDate: DateTime(2026, 10, 14),
        categoryId: food,
      );

      final item = await read(id);
      expect(item.challenge.title, 'Now nothing');
      expect(item.challenge.kind, ChallengeKind.noSpend);
      expect(item.challenge.limit, 0);
      expect(item.challenge.days, 3);
      expect(item.categoryName, 'Food');
    });

    test('update can take the category away', () async {
      final id = await week(category: food);

      await repo.update(
        id,
        title: 'All spending',
        kind: ChallengeKind.limit,
        startDate: start,
        endDate: end,
        limit: 100000,
      );

      expect((await read(id)).challenge.categoryId, isNull);
    });

    test('update keeps a category that was archived after the start', () async {
      final id = await week(category: food);
      await db.categoriesDao.setArchived(food, archived: true);

      await repo.update(
        id,
        title: 'Renamed',
        kind: ChallengeKind.limit,
        startDate: start,
        endDate: end,
        limit: 100000,
        categoryId: food,
      );

      expect((await read(id)).challenge.categoryId, food);
    });

    test('update of a missing challenge is refused', () async {
      await expectLater(
        repo.update(
          404,
          title: 'x',
          kind: ChallengeKind.noSpend,
          startDate: start,
          endDate: end,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('delete removes it', () async {
      final id = await week();

      await repo.delete(id);

      expect(await repo.getChallenge(id), isNull);
      expect(await repo.watchChallenges().first, isEmpty);
    });
  });

  group('cheering a win', () {
    final today = DateTime(2026, 10, 20, 9);

    Future<ChallengeItem> over(DateTime ended, {int spent = 0}) async {
      final id = await repo.create(
        title: 'Past',
        kind: ChallengeKind.limit,
        startDate: ended.subtract(const Duration(days: 6)),
        endDate: ended,
        limit: 100000,
      );
      if (spent > 0) {
        await add(spent, ended, category: food);
      }
      return read(id);
    }

    test('a win that just ended is worth confetti, once', () async {
      final won = await over(DateTime(2026, 10, 18));

      expect(await repo.takeNewWins([won], today), isTrue);
      expect(await repo.takeNewWins([won], today), isFalse);
    });

    test('an old win is remembered but not cheered', () async {
      final won = await over(DateTime(2026, 9, 1));

      expect(await repo.takeNewWins([won], today), isFalse);
      // And it stays quiet afterwards.
      expect(await repo.takeNewWins([won], today), isFalse);
    });

    test(
      'a broken challenge, a running one and a coming one are not wins',
      () async {
        final broken = await over(DateTime(2026, 10, 18), spent: 200000);
        final running = await read(
          await repo.create(
            title: 'Now',
            kind: ChallengeKind.noSpend,
            startDate: DateTime(2026, 10, 19),
            endDate: DateTime(2026, 10, 25),
          ),
        );
        final coming = await read(
          await repo.create(
            title: 'Later',
            kind: ChallengeKind.noSpend,
            startDate: DateTime(2026, 11),
            endDate: DateTime(2026, 11, 7),
          ),
        );

        expect(
          await repo.takeNewWins([broken, running, coming], today),
          isFalse,
        );
      },
    );

    test('a second win is cheered when it comes', () async {
      final first = await over(DateTime(2026, 10, 18));
      expect(await repo.takeNewWins([first], today), isTrue);

      final second = await over(DateTime(2026, 10, 19));

      expect(await repo.takeNewWins([first, second], today), isTrue);
    });
  });

  group('repeating', () {
    Future<int> repeating({
      DateTime? from,
      DateTime? to,
      bool repeats = true,
      int? category,
      int limit = 0,
      ChallengeKind kind = ChallengeKind.noSpend,
    }) => repo.create(
      title: 'Every week',
      kind: kind,
      startDate: from ?? DateTime(2026, 10, 11),
      endDate: to ?? DateTime(2026, 10, 17),
      limit: limit,
      categoryId: category,
      repeats: repeats,
    );

    test('a challenge that repeats keeps the choice', () async {
      final id = await repeating();

      expect((await read(id)).challenge.repeats, isTrue);
      expect((await read(await week())).challenge.repeats, isFalse);
    });

    test('starts the next round the day after it ended', () async {
      final old = await repeating(category: food);

      final made = await repo.renewRepeating(DateTime(2026, 10, 18, 9));

      expect(made, 1);
      final items = await repo.watchChallenges().first;
      expect(items, hasLength(2));
      final next = items.firstWhere((i) => i.challenge.id != old).challenge;
      expect(next.title, 'Every week');
      expect(next.startDate, DateTime(2026, 10, 18));
      expect(next.endDate, DateTime(2026, 10, 24));
      expect(next.categoryId, food);
      expect(next.repeats, isTrue);
      // The old one stops repeating; the new one carries it on.
      expect((await read(old)).challenge.repeats, isFalse);
    });

    test('does not start another while one is running or coming', () async {
      await repeating();

      expect(await repo.renewRepeating(DateTime(2026, 10, 14)), 0);
      expect(await repo.renewRepeating(DateTime(2026, 10, 17, 23)), 0);
      expect(await repo.watchChallenges().first, hasLength(1));
    });

    test('does it once, however often it is asked', () async {
      await repeating();

      expect(await repo.renewRepeating(DateTime(2026, 10, 18)), 1);
      expect(await repo.renewRepeating(DateTime(2026, 10, 18)), 0);
      expect(await repo.renewRepeating(DateTime(2026, 10, 20)), 0);
      expect(await repo.watchChallenges().first, hasLength(2));
    });

    test('skips the rounds that passed while the app was closed', () async {
      await repeating();

      // 25 October is the first day of the round after 18 to 24 October.
      await repo.renewRepeating(DateTime(2026, 10, 25));

      final next = (await repo.watchChallenges().first).first.challenge;
      expect(next.startDate, DateTime(2026, 10, 25));
      expect(next.endDate, DateTime(2026, 10, 31));
    });

    test('lands in the round that today is in', () async {
      await repeating();

      await repo.renewRepeating(DateTime(2026, 11, 20));

      final next = (await repo.watchChallenges().first).first.challenge;
      expect(next.startDate, DateTime(2026, 11, 15));
      expect(next.endDate, DateTime(2026, 11, 21));
    });

    test('a challenge that does not repeat is left alone', () async {
      await repeating(repeats: false);

      expect(await repo.renewRepeating(DateTime(2026, 11, 30)), 0);
    });

    test('keeps the limit of a limit challenge', () async {
      await repeating(kind: ChallengeKind.limit, limit: 250000);

      await repo.renewRepeating(DateTime(2026, 10, 18));

      final next = (await repo.watchChallenges().first).first.challenge;
      expect(next.kind, ChallengeKind.limit);
      expect(next.limit, 250000);
    });

    test('update can switch repeating on and off', () async {
      final id = await repeating(repeats: false);

      await repo.update(
        id,
        title: 'Every week',
        kind: ChallengeKind.noSpend,
        startDate: DateTime(2026, 10, 11),
        endDate: DateTime(2026, 10, 17),
        repeats: true,
      );
      expect((await read(id)).challenge.repeats, isTrue);
    });
  });
}
