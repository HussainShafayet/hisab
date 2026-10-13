import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);
final monthStart = DateTime(2026, 10);
final monthEnd = DateTime(2026, 11);

void main() {
  late AppDatabase db;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;
  late int card;
  late int bank;
  late int shopping;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    accounts = AccountsRepository(db);
    transactions = TransactionsRepository(db);
    card = await accounts.createAccount(
      name: 'EBL',
      type: AccountType.creditCard,
      creditLimit: 12000000,
      usdLimit: 25000,
    );
    bank = await insertTestAccount(db, name: 'Bank', type: AccountType.bank);
    shopping = await insertTestCategory(db, name: 'Shopping');
    salary = await insertTestCategory(
      db,
      name: 'Refund',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<int> spend(int taka, int usd, {DateTime? on}) =>
      transactions.addTransaction(
        TransactionInput(
          type: TransactionType.expense,
          amount: taka,
          accountId: card,
          categoryId: shopping,
          date: on ?? DateTime(2026, 10, 5),
          usdAmount: usd,
        ),
      );

  Future<int> payBill(int taka, int? usd) => transactions.addTransaction(
    TransactionInput(
      type: TransactionType.transfer,
      amount: taka,
      accountId: bank,
      toAccountId: card,
      date: DateTime(2026, 10, 9),
      usdAmount: usd,
    ),
  );

  Future<Map<int, CardDollars>> dollars() =>
      accounts.watchCardDollars(monthStart, monthEnd).first;

  group('a card with a dollar limit', () {
    test('keeps it, and a plain card has none', () async {
      expect((await accounts.getAccount(card))!.usdLimit, 25000);
      final plain = await accounts.createAccount(
        name: 'Visa',
        type: AccountType.creditCard,
      );
      expect((await accounts.getAccount(plain))!.usdLimit, isNull);
    });

    test('must be above zero', () async {
      await expectLater(
        accounts.createAccount(
          name: 'Bad',
          type: AccountType.creditCard,
          usdLimit: 0,
        ),
        throwsValidation('dollar limit'),
      );
    });

    test('is dropped when the account is not a credit card', () async {
      final id = await accounts.createAccount(
        name: 'Cash2',
        type: AccountType.cash,
        usdLimit: 1000,
      );

      expect((await accounts.getAccount(id))!.usdLimit, isNull);
    });
  });

  group('dollars on a transaction', () {
    test('are saved and read back', () async {
      final id = await spend(305000, 2500);

      final item = (await transactions.getTransaction(id))!;

      expect(item.amount, 305000);
      expect(item.usdAmount, 2500);
    });

    test('can be changed or removed when editing', () async {
      final id = await spend(305000, 2500);
      await transactions.updateTransaction(
        id,
        TransactionInput(
          type: TransactionType.expense,
          amount: 310000,
          accountId: card,
          categoryId: shopping,
          date: DateTime(2026, 10, 5),
          usdAmount: 2600,
        ),
      );
      expect((await transactions.getTransaction(id))!.usdAmount, 2600);

      await transactions.updateTransaction(
        id,
        TransactionInput(
          type: TransactionType.expense,
          amount: 310000,
          accountId: card,
          categoryId: shopping,
          date: DateTime(2026, 10, 5),
        ),
      );
      expect((await transactions.getTransaction(id))!.usdAmount, isNull);
    });

    test('come back with an undone delete', () async {
      final id = await spend(305000, 2500);

      final deleted = (await transactions.deleteTransaction(id))!;
      await transactions.restoreTransaction(deleted);

      expect((await transactions.getTransaction(id))!.usdAmount, 2500);
    });

    test('must be above zero', () async {
      await expectLater(spend(305000, 0), throwsValidation('dollar amount'));
    });

    test('are refused on an account that is not a credit card', () async {
      await expectLater(
        transactions.addTransaction(
          TransactionInput(
            type: TransactionType.expense,
            amount: 1000,
            accountId: bank,
            categoryId: shopping,
            date: DateTime(2026, 10, 5),
            usdAmount: 100,
          ),
        ),
        throwsValidation('credit card'),
      );
    });

    test('on a transfer must go into a credit card', () async {
      await expectLater(
        transactions.addTransaction(
          TransactionInput(
            type: TransactionType.transfer,
            amount: 1000,
            accountId: card,
            toAccountId: bank,
            date: DateTime(2026, 10, 5),
            usdAmount: 100,
          ),
        ),
        throwsValidation('credit card'),
      );
    });
  });

  group('the dollars of a card', () {
    test('are empty until there is a dollar entry', () async {
      expect(await dollars(), isEmpty);
    });

    test('add up what was spent, and what was spent this month', () async {
      await spend(305000, 2500); // 5 October
      await spend(610000, 5000, on: DateTime(2026, 9, 20));

      final d = (await dollars())[card]!;

      expect(d.spent, 7500);
      expect(d.spentThisMonth, 2500);
    });

    test('go down with a refund and with a bill payment', () async {
      await spend(1220000, 10000);
      await transactions.addTransaction(
        TransactionInput(
          type: TransactionType.income,
          amount: 122000,
          accountId: card,
          categoryId: salary,
          date: DateTime(2026, 10, 7),
          usdAmount: 1000,
        ),
      );
      await payBill(610000, 5000);

      final d = (await dollars())[card]!;

      expect(d.spent, 10000);
      expect(d.refunded, 1000);
      expect(d.settled, 5000);
      expect(d.due, 4000);
    });

    test('count a payment without dollars as taka only', () async {
      await spend(1220000, 10000);
      await payBill(500000, null);

      expect((await dollars())[card]!.due, 10000);
    });

    test('take the rate from the latest dollar expense', () async {
      await spend(1200000, 10000, on: DateTime(2026, 10, 2)); // 120
      await spend(1230000, 10000, on: DateTime(2026, 10, 6)); // 123

      expect((await dollars())[card]!.lastRate, closeTo(123, 0.0001));
    });

    test('follow the data when it changes', () async {
      final spent = accounts
          .watchCardDollars(monthStart, monthEnd)
          .map((m) => m[card]?.spent ?? 0)
          .firstWhere((value) => value == 2500);

      await spend(305000, 2500);

      expect(await spent, 2500);
    });
  });

  group('backup', () {
    test('keeps the dollar limit and the dollars of a transaction', () async {
      final id = await spend(305000, 2500);
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      final restoredCard = (await AccountsRepository(
        other,
      ).getAccounts()).firstWhere((a) => a.name == 'EBL');
      expect(restoredCard.usdLimit, 25000);
      final restored = (await TransactionsRepository(other)
          .getTransaction(id))!;
      expect(restored.usdAmount, 2500);
    });

    test('an older backup without dollars still restores', () async {
      await spend(305000, 2500);
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 4;
      for (final account in (json['accounts']! as List).cast<Map>()) {
        account.remove('usdLimit');
      }
      for (final t in (json['transactions']! as List).cast<Map>()) {
        t.remove('usdAmount');
      }

      final read = BackupData.fromJson(json);

      expect(read.accounts.first.usdLimit, isNull);
      expect(read.transactions.first.usdAmount, isNull);
    });
  });
}
