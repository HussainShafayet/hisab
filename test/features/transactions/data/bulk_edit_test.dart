import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;
  late Basics b;
  late int lunch;
  late int rickshaw;
  late int pay;
  late int move;

  setUp(() async {
    db = createTestDatabase();
    repo = TransactionsRepository(db);
    b = await seedBasics(db);
    lunch = await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 25000,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 11, 12),
    );
    rickshaw = await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 8000,
      accountId: b.bkash,
      categoryId: b.transport,
      date: DateTime(2026, 10, 10, 18),
    );
    pay = await addTransaction(
      db,
      type: TransactionType.income,
      amount: 5000000,
      accountId: b.cash,
      categoryId: b.salary,
      date: DateTime(2026, 10, 11, 9),
    );
    move = await addTransaction(
      db,
      type: TransactionType.transfer,
      amount: 100000,
      accountId: b.cash,
      toAccountId: b.bkash,
      date: DateTime(2026, 10, 9, 10),
    );
  });
  tearDown(() => db.close());

  Future<TransactionRow> row(int id) async =>
      (await db.transactionsDao.getById(id))!;

  group('deleting several', () {
    test('removes them together and gives back what was removed', () async {
      final deleted = await repo.deleteTransactions([lunch, rickshaw]);

      expect(deleted.map((t) => t.id), [lunch, rickshaw]);
      expect(await db.transactionsDao.getById(lunch), isNull);
      expect(await db.transactionsDao.getById(rickshaw), isNull);
      expect(await db.transactionsDao.getById(pay), isNotNull);
    });

    test('puts them back as they were, with the same ids', () async {
      final before = await row(lunch);
      final deleted = await repo.deleteTransactions([lunch, move]);

      await repo.restoreTransactions(deleted);

      final after = await row(lunch);
      expect(after.amount, before.amount);
      expect(after.categoryId, before.categoryId);
      expect(after.date, before.date);
      expect((await row(move)).toAccountId, b.bkash);
    });

    test('one that is not there is skipped', () async {
      final deleted = await repo.deleteTransactions([lunch, 99999]);

      expect(deleted.map((t) => t.id), [lunch]);
    });
  });

  group('changing the category of several', () {
    test('moves them all and remembers where they were', () async {
      final before = await repo.changeCategories([lunch, rickshaw], b.food);

      expect(before, {lunch: b.food, rickshaw: b.transport});
      expect((await row(lunch)).categoryId, b.food);
      expect((await row(rickshaw)).categoryId, b.food);
    });

    test('can be taken back', () async {
      final before = await repo.changeCategories([lunch, rickshaw], b.food);

      await repo.restoreCategories(before);

      expect((await row(lunch)).categoryId, b.food);
      expect((await row(rickshaw)).categoryId, b.transport);
    });

    test('all of them or none: one that does not fit stops it', () async {
      // The income does not fit an expense category.
      await expectLater(
        repo.changeCategories([rickshaw, pay], b.food),
        throwsA(isA<ValidationException>()),
      );

      expect((await row(rickshaw)).categoryId, b.transport);
      expect((await row(pay)).categoryId, b.salary);
    });

    test('an income needs an income category', () async {
      final bonus = await insertTestCategory(
        db,
        name: 'Bonus',
        type: CategoryType.income,
      );

      await repo.changeCategories([pay], bonus);

      expect((await row(pay)).categoryId, bonus);
      await expectLater(
        repo.changeCategories([pay], b.food),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a transfer has no category to change', () async {
      await expectLater(
        repo.changeCategories([move], b.food),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a balance fix is left alone', () async {
      final fix = await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: 500,
          accountId: b.cash,
          categoryId: Value(b.food),
          date: DateTime(2026, 10, 1),
          isAdjustment: const Value(true),
        ),
      );

      await expectLater(
        repo.changeCategories([fix], b.transport),
        throwsA(isA<ValidationException>()),
      );
    });

    test('an archived or missing category is refused', () async {
      final old = await insertTestCategory(db, name: 'Old');
      await db.categoriesDao.setArchived(old, archived: true);

      await expectLater(
        repo.changeCategories([lunch], old),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repo.changeCategories([lunch], 99999),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a transaction that is not there is refused', () async {
      await expectLater(
        repo.changeCategories([lunch, 99999], b.transport),
        throwsA(isA<ValidationException>()),
      );

      expect((await row(lunch)).categoryId, b.food);
    });
  });

  group('changing the account of several', () {
    test('moves them all and remembers where they were', () async {
      final before = await repo.changeAccounts([lunch, pay], b.bkash);

      expect(before, {lunch: b.cash, pay: b.cash});
      expect((await row(lunch)).accountId, b.bkash);
      expect((await row(pay)).accountId, b.bkash);
    });

    test('can be taken back', () async {
      final before = await repo.changeAccounts([lunch, rickshaw], b.cash);

      await repo.restoreAccounts(before);

      expect((await row(lunch)).accountId, b.cash);
      expect((await row(rickshaw)).accountId, b.bkash);
    });

    test('a transfer cannot be moved this way, and nothing changes', () async {
      await expectLater(
        repo.changeAccounts([lunch, move], b.bkash),
        throwsA(isA<ValidationException>()),
      );

      expect((await row(lunch)).accountId, b.cash);
    });

    test('an archived or missing account is refused', () async {
      final old = await insertTestAccount(db, name: 'Old');
      await db.accountsDao.setArchived(old, archived: true);

      await expectLater(
        repo.changeAccounts([lunch], old),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repo.changeAccounts([lunch], 99999),
        throwsA(isA<ValidationException>()),
      );
    });

    test('dollars need a credit card', () async {
      final card = await insertTestAccount(
        db,
        name: 'EBL card',
        type: AccountType.creditCard,
      );
      final usd = await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: 120000,
          accountId: card,
          categoryId: Value(b.food),
          date: DateTime(2026, 10, 5),
          usdAmount: const Value(1000),
        ),
      );

      await expectLater(
        repo.changeAccounts([usd], b.cash),
        throwsA(isA<ValidationException>()),
      );
      final other = await insertTestAccount(
        db,
        name: 'City card',
        type: AccountType.creditCard,
      );
      await repo.changeAccounts([usd], other);
      expect((await row(usd)).accountId, other);
    });
  });
}
