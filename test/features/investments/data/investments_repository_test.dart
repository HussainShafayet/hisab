import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';

import '../../../helpers/test_database.dart';

final day = DateTime(2026, 10, 5);

void main() {
  late AppDatabase db;
  late InvestmentsRepository repo;
  late int cash;

  setUp(() async {
    db = createTestDatabase();
    repo = InvestmentsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
  });
  tearDown(() => db.close());

  Future<int> farm() =>
      repo.createInvestment(name: 'Poultry farm', startedOn: day);

  Future<int> put(int id, int amount, {int? account}) => repo.addEntry(
    id,
    kind: InvestmentEntryKind.putIn,
    amount: amount,
    date: day,
    accountId: account,
  );

  Future<int> profit(int id, int amount, {int? account}) => repo.addEntry(
    id,
    kind: InvestmentEntryKind.profit,
    amount: amount,
    date: day,
    accountId: account,
  );

  Future<int> back(int id, int amount, {int? account}) => repo.addEntry(
    id,
    kind: InvestmentEntryKind.takeBack,
    amount: amount,
    date: day,
    accountId: account,
  );

  Future<int> balance(int account) async => (await AccountsRepository(
    db,
  ).watchAccounts().first).firstWhere((a) => a.account.id == account).balance;

  group('making and changing', () {
    test('creates an investment with a clean name and note', () async {
      final id = await repo.createInvestment(
        name: '  Poultry farm ',
        note: ' with Rahim ',
        startedOn: DateTime(2026, 10, 5, 14, 30),
      );

      final item = (await repo.getInvestment(id))!;
      expect(item.investment.name, 'Poultry farm');
      expect(item.investment.note, 'with Rahim');
      expect(item.investment.startedOn, DateTime(2026, 10, 5));
      expect(item.investment.isClosed, isFalse);
      expect(item.investment.currentValue, isNull);
      expect(item.putIn, 0);
    });

    test('needs a name that is not too long', () async {
      await expectLater(
        repo.createInvestment(name: '   ', startedOn: day),
        throwsValidation('name'),
      );
      await expectLater(
        repo.createInvestment(name: 'x' * 61, startedOn: day),
        throwsValidation('60'),
      );
      await expectLater(
        repo.createInvestment(name: 'A', note: 'x' * 201, startedOn: day),
        throwsValidation('200'),
      );
    });

    test('can be renamed and moved to another start day', () async {
      final id = await farm();

      await repo.updateInvestment(
        id,
        name: 'Fish farm',
        note: 'moved',
        startedOn: DateTime(2026, 9, 1),
      );

      final item = (await repo.getInvestment(id))!;
      expect(item.investment.name, 'Fish farm');
      expect(item.investment.note, 'moved');
      expect(item.investment.startedOn, DateTime(2026, 9, 1));
    });

    test('cannot be changed once gone', () async {
      await expectLater(
        repo.updateInvestment(99, name: 'X', startedOn: day),
        throwsValidation('not found'),
      );
      await expectLater(
        repo.setClosed(99, closed: true),
        throwsValidation('not found'),
      );
      await expectLater(
        repo.deleteInvestment(99),
        throwsValidation('not found'),
      );
    });

    test(
      'sets, changes and clears the value, which cannot be negative',
      () async {
        final id = await farm();

        await repo.setCurrentValue(id, 750000);
        expect((await repo.getInvestment(id))!.investment.currentValue, 750000);
        await repo.setCurrentValue(id, 0);
        expect((await repo.getInvestment(id))!.investment.currentValue, 0);
        await repo.setCurrentValue(id, null);
        expect((await repo.getInvestment(id))!.investment.currentValue, isNull);
        await expectLater(
          repo.setCurrentValue(id, -1),
          throwsValidation('negative'),
        );
      },
    );

    test('closes and opens again', () async {
      final id = await farm();

      await repo.setClosed(id, closed: true);
      expect((await repo.getInvestment(id))!.investment.isClosed, isTrue);
      await repo.setClosed(id, closed: false);
      expect((await repo.getInvestment(id))!.investment.isClosed, isFalse);
    });
  });

  group('the lines', () {
    test('add up by kind', () async {
      final id = await farm();
      await put(id, 1000000);
      await put(id, 500000);
      await profit(id, 120000);
      await profit(id, 30000);
      await back(id, 200000);

      final item = (await repo.getInvestment(id))!;
      expect(item.putIn, 1500000);
      expect(item.profit, 150000);
      expect(item.takenBack, 200000);
      expect(item.stillIn, 1300000);
      expect(item.totalReturn, 150000);
    });

    test('keep one investment apart from another', () async {
      final a = await farm();
      final b = await repo.createInvestment(name: 'Shop', startedOn: day);
      await put(a, 100);
      await put(b, 700);

      expect((await repo.getInvestment(a))!.putIn, 100);
      expect((await repo.getInvestment(b))!.putIn, 700);
    });

    test('need an amount above zero and a short note', () async {
      final id = await farm();

      await expectLater(put(id, 0), throwsValidation('above zero'));
      await expectLater(put(id, -5), throwsValidation('above zero'));
      await expectLater(
        repo.addEntry(
          id,
          kind: InvestmentEntryKind.putIn,
          amount: 1,
          date: day,
          note: 'x' * 201,
        ),
        throwsValidation('200'),
      );
    });

    test('need an investment that is there', () async {
      await expectLater(put(99, 100), throwsValidation('not found'));
    });

    test(
      'cannot take back more than is still in: the rest is profit',
      () async {
        final id = await farm();
        await put(id, 1000000);
        await back(id, 400000);

        await expectLater(back(id, 600001), throwsValidation('profit'));
        // Exactly what is left is fine.
        await back(id, 600000);
        expect((await repo.getInvestment(id))!.stillIn, 0);
        await expectLater(back(id, 1), throwsValidation('No money is left'));
      },
    );

    test('can have any amount of profit', () async {
      final id = await farm();
      await put(id, 100);

      await profit(id, 999999999);

      expect((await repo.getInvestment(id))!.profit, 999999999);
    });

    test('a closed investment takes no more money in', () async {
      final id = await farm();
      await put(id, 1000);
      await repo.setClosed(id, closed: true);

      await expectLater(put(id, 100), throwsValidation('closed'));
      // Profit and money back still can be recorded.
      await profit(id, 50);
      await back(id, 500);
    });

    test('are listed newest first', () async {
      final id = await farm();
      await repo.addEntry(
        id,
        kind: InvestmentEntryKind.putIn,
        amount: 1,
        date: DateTime(2026, 10, 1),
      );
      await repo.addEntry(
        id,
        kind: InvestmentEntryKind.profit,
        amount: 2,
        date: DateTime(2026, 10, 9),
      );
      await repo.addEntry(
        id,
        kind: InvestmentEntryKind.putIn,
        amount: 3,
        date: DateTime(2026, 10, 5),
      );

      final entries = await repo.watchEntries(id).first;

      expect(entries.map((e) => e.amount), [2, 3, 1]);
    });

    test('can be deleted one by one', () async {
      final id = await farm();
      final first = await put(id, 1000);
      await put(id, 500);

      await repo.deleteEntry(first);

      expect((await repo.getInvestment(id))!.putIn, 500);
      await expectLater(repo.deleteEntry(first), throwsValidation('not found'));
    });
  });

  group('the investments', () {
    test('are listed oldest first with their sums', () async {
      final a = await farm();
      final b = await repo.createInvestment(name: 'Shop', startedOn: day);
      await put(a, 100);
      await profit(b, 30);

      final items = await repo.watchInvestments().first;

      expect(items.map((i) => i.investment.id), [a, b]);
      expect(items.map((i) => i.putIn), [100, 0]);
      expect(items.map((i) => i.profit), [0, 30]);
    });

    test('are empty to begin with', () async {
      expect(await repo.watchInvestments().first, isEmpty);
    });
  });

  group('with an account', () {
    test('money put in leaves the account but is not spending', () async {
      final id = await farm();

      await put(id, 500000, account: cash);

      expect(await balance(cash), -500000);
      final totals = await ReportsRepository(db).totals(monthRange(day));
      expect(totals.expense, 0);
      expect(totals.income, 0);
      final categories = await db.categoriesDao.getAll();
      final category = categories.singleWhere((c) => c.name == 'Investments');
      expect(category.type, CategoryType.expense);
    });

    test('money taken back arrives but is not income', () async {
      final id = await farm();
      await put(id, 500000);

      await back(id, 200000, account: cash);

      expect(await balance(cash), 200000);
      final totals = await ReportsRepository(db).totals(monthRange(day));
      expect(totals.income, 0);
      final categories = await db.categoriesDao.getAll();
      final category = categories.singleWhere(
        (c) => c.name == 'Investments' && c.type == CategoryType.income,
      );
      expect(category.parentId, isNull);
    });

    test('profit arrives and is income', () async {
      final id = await farm();

      await profit(id, 150000, account: cash);

      expect(await balance(cash), 150000);
      final totals = await ReportsRepository(db).totals(monthRange(day));
      expect(totals.income, 150000);
      expect(totals.expense, 0);
      final categories = await db.categoriesDao.getAll();
      final category = categories.singleWhere(
        (c) => c.name == 'Investment profit',
      );
      expect(category.type, CategoryType.income);
    });

    test('names the business in the note of the transaction', () async {
      final id = await farm();
      await put(id, 100, account: cash);

      final all = await db.transactionsDao.getAll();

      expect(all.single.note, 'Poultry farm');
      expect(all.single.isAdjustment, isTrue);
    });

    test('uses one category however many lines', () async {
      final id = await farm();
      await put(id, 100, account: cash);
      await put(id, 200, account: cash);
      await profit(id, 5, account: cash);
      await profit(id, 6, account: cash);

      final categories = await db.categoriesDao.getAll();

      expect(categories.where((c) => c.name == 'Investments'), hasLength(1));
      expect(
        categories.where((c) => c.name == 'Investment profit'),
        hasLength(1),
      );
    });

    test('a line with no account changes no balance', () async {
      final id = await farm();

      await put(id, 500000);
      await profit(id, 1000);

      expect(await balance(cash), 0);
      expect(await db.transactionsDao.getAll(), isEmpty);
    });

    test(
      'an archived or unknown account is refused, and nothing is saved',
      () async {
        final id = await farm();
        final old = await insertTestAccount(db, name: 'Old');
        await db.accountsDao.setArchived(old, archived: true);

        await expectLater(
          put(id, 100, account: old),
          throwsValidation('archived'),
        );
        await expectLater(
          put(id, 100, account: 999),
          throwsValidation('not found'),
        );
        expect((await repo.getInvestment(id))!.putIn, 0);
        expect(await db.transactionsDao.getAll(), isEmpty);
      },
    );

    test('a refused line leaves no half-made transaction behind', () async {
      final id = await farm();

      await expectLater(
        back(id, 100, account: cash),
        throwsValidation('No money'),
      );

      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await balance(cash), 0);
    });

    test('deleting a line takes the balance change back', () async {
      final id = await farm();
      final entry = await put(id, 500000, account: cash);
      expect(await balance(cash), -500000);

      await repo.deleteEntry(entry);

      expect(await balance(cash), 0);
      expect(await db.transactionsDao.getAll(), isEmpty);
    });

    test('deleting the investment takes every balance change back', () async {
      final id = await farm();
      await put(id, 500000, account: cash);
      await profit(id, 70000, account: cash);
      await back(id, 100000, account: cash);

      await repo.deleteInvestment(id);

      expect(await balance(cash), 0);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await repo.watchInvestments().first, isEmpty);
      expect(await db.investmentsDao.getAllEntries(), isEmpty);
    });
  });
}
