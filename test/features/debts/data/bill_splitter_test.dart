import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/debts/data/bill_splitter.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/split.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';

import '../../../helpers/test_database.dart';

final day = DateTime(2026, 10, 9, 20);

void main() {
  late AppDatabase db;
  late BillSplitter splitter;
  late int cash;
  late int food;

  setUp(() async {
    db = createTestDatabase();
    splitter = BillSplitter(db);
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
  });
  tearDown(() => db.close());

  Future<int> balance() async {
    final accounts = await AccountsRepository(db).watchAccounts().first;
    return accounts.firstWhere((a) => a.account.id == cash).balance;
  }

  Future<SplitResult> split({
    int total = 120000,
    List<SplitShare>? friends,
    String title = 'Lunch',
  }) => splitter.split(
    total: total,
    accountId: cash,
    categoryId: food,
    date: day,
    title: title,
    friends:
        friends ??
        const [
          SplitShare(person: 'Rahim', amount: 30000),
          SplitShare(person: 'Karim', amount: 30000),
        ],
  );

  group('splitting a bill', () {
    test('takes the whole bill out of the account', () async {
      await split();

      expect(await balance(), -120000);
    });

    test('makes your part an expense', () async {
      final result = await split();

      expect(result.mine, 60000);
      final expense = (await db.transactionsDao.getAll()).firstWhere(
        (t) => t.id == result.transactionId,
      );
      expect(expense.amount, 60000);
      expect(expense.categoryId, food);
      expect(expense.isAdjustment, isFalse);
      expect(expense.note, 'Lunch (my part of ৳1,200.00)');
    });

    test('lends each friend their part', () async {
      final result = await split();

      expect(result.debtIds, hasLength(2));
      final debts = await DebtsRepository(db).watchDebts().first;
      expect(debts.map((d) => d.debt.person).toSet(), {'Rahim', 'Karim'});
      expect(debts.map((d) => d.debt.amount), [30000, 30000]);
      expect(
        debts.every((d) => d.debt.direction == DebtDirection.lent),
        isTrue,
      );
      expect(debts.first.debt.note, 'Lunch');
    });

    test('counts only your part as spending', () async {
      await split();

      final totals = await ReportsRepository(db)
          .totals((start: DateTime(2026, 10), end: DateTime(2026, 11)));

      expect(totals.expense, 60000);
    });

    test('has no expense when you paid nothing for yourself', () async {
      final result = await split(
        total: 60000,
        friends: const [
          SplitShare(person: 'Rahim', amount: 30000),
          SplitShare(person: 'Karim', amount: 30000),
        ],
      );

      expect(result.mine, 0);
      expect(result.transactionId, isNull);
      expect(await balance(), -60000);
    });

    test('names a bill with no title', () async {
      final result = await split(title: '  ');

      final expense = (await db.transactionsDao.getAll()).firstWhere(
        (t) => t.id == result.transactionId,
      );
      expect(expense.note, startsWith('Split bill'));
    });
  });

  group('refusing a split', () {
    Future<void> expectNothingSaved() async {
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await DebtsRepository(db).watchDebts().first, isEmpty);
    }

    test('without friends', () async {
      await expectLater(split(friends: []), throwsValidation('friend'));
      await expectNothingSaved();
    });

    test('with parts above the bill', () async {
      await expectLater(
        split(
          total: 50000,
          friends: const [
            SplitShare(person: 'Rahim', amount: 30000),
            SplitShare(person: 'Karim', amount: 30000),
          ],
        ),
        throwsValidation('more than the bill'),
      );
      await expectNothingSaved();
    });

    test('with a friend twice, whatever the case', () async {
      await expectLater(
        split(
          friends: const [
            SplitShare(person: 'Rahim', amount: 10000),
            SplitShare(person: ' rahim ', amount: 10000),
          ],
        ),
        throwsValidation('twice'),
      );
      await expectNothingSaved();
    });

    test('with a part of nothing', () async {
      await expectLater(
        split(friends: const [SplitShare(person: 'Rahim', amount: 0)]),
        throwsValidation('above zero'),
      );
    });

    test('with a friend without a name', () async {
      await expectLater(
        split(friends: const [SplitShare(person: '  ', amount: 100)]),
        throwsValidation('name'),
      );
    });

    test('with a bill of nothing', () async {
      await expectLater(split(total: 0), throwsValidation('above zero'));
    });

    test('with too many friends', () async {
      await expectLater(
        split(
          total: 10000000,
          friends: [
            for (var i = 0; i <= maxSplitFriends; i++)
              SplitShare(person: 'Friend $i', amount: 100),
          ],
        ),
        throwsValidation('at most'),
      );
    });

    test('and saves nothing when a loan fails half way', () async {
      // The second friend's name is too long for a loan.
      await expectLater(
        split(
          friends: [
            const SplitShare(person: 'Rahim', amount: 10000),
            SplitShare(person: 'x' * 61, amount: 10000),
          ],
        ),
        throwsValidation(),
      );
      await expectNothingSaved();
      expect(await balance(), 0);
    });
  });
}
