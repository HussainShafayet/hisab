import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late AccountsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = AccountsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> makeCard({
    String name = 'Visa',
    int? limit = 5000000,
    int? day = 15,
    int opening = 0,
  }) => repo.createAccount(
    name: name,
    type: AccountType.creditCard,
    openingBalance: opening,
    creditLimit: limit,
    billDueDay: day,
  );

  group('a credit card account', () {
    test('keeps its limit and bill day', () async {
      final id = await makeCard();

      final account = (await repo.getAccount(id))!;

      expect(account.type, AccountType.creditCard);
      expect(account.isCreditCard, isTrue);
      expect(account.creditLimit, 5000000);
      expect(account.billDueDay, 15);
    });

    test('can be without a limit and a bill day', () async {
      final id = await makeCard(limit: null, day: null);

      final account = (await repo.getAccount(id))!;

      expect(account.creditLimit, isNull);
      expect(account.billDueDay, isNull);
    });

    test('can change them, and lose them', () async {
      final id = await makeCard();

      await repo.updateAccount(
        id,
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalance: 0,
        includeInTotal: true,
        creditLimit: 800000,
        billDueDay: 3,
      );
      var account = (await repo.getAccount(id))!;
      expect(account.creditLimit, 800000);
      expect(account.billDueDay, 3);

      await repo.updateAccount(
        id,
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalance: 0,
        includeInTotal: true,
      );
      account = (await repo.getAccount(id))!;
      expect(account.creditLimit, isNull);
      expect(account.billDueDay, isNull);
    });

    test('is the only kind that keeps them', () async {
      final bank = await repo.createAccount(
        name: 'Bank',
        type: AccountType.bank,
        creditLimit: 100000,
        billDueDay: 10,
      );
      expect((await repo.getAccount(bank))!.creditLimit, isNull);
      expect((await repo.getAccount(bank))!.billDueDay, isNull);

      final card = await makeCard();
      await repo.updateAccount(
        card,
        name: 'Visa',
        type: AccountType.card,
        openingBalance: 0,
        includeInTotal: true,
        creditLimit: 100000,
        billDueDay: 10,
      );
      expect((await repo.getAccount(card))!.creditLimit, isNull);
      expect((await repo.getAccount(card))!.billDueDay, isNull);
    });

    test('needs a limit above zero and a bill day from 1 to 31', () async {
      expect(() => makeCard(limit: 0), throwsValidation('above zero'));
      expect(() => makeCard(day: 0), throwsValidation('1 to 31'));
      expect(() => makeCard(day: 32), throwsValidation('1 to 31'));
      await makeCard(name: 'A', day: 1);
      await makeCard(name: 'B', day: 31);
    });

    test(
      'owes what it was spent on, and paying it off brings it to zero',
      () async {
        final card = await makeCard(opening: -20000);
        final bank = await insertTestAccount(db, name: 'Bank');
        Future<void> add(
          TransactionType type,
          int amount,
          int account, {
          int? to,
        }) async {
          await db.transactionsDao.insertTransaction(
            TransactionsCompanion.insert(
              type: type,
              amount: amount,
              accountId: account,
              toAccountId: Value(to),
              date: now,
            ),
          );
        }

        // 300 spent with the card.
        await add(TransactionType.expense, 30000, card);
        var accounts = await repo.watchAccounts().first;
        var status = creditCardsOf(accounts).single;
        expect(status.balance, -50000);
        expect(status.owed, 50000);

        // The bill is paid from the bank: a transfer into the card.
        await add(TransactionType.transfer, 50000, bank, to: card);
        accounts = await repo.watchAccounts().first;
        status = creditCardsOf(accounts).single;
        expect(status.owed, 0);
        expect(
          accounts.firstWhere((a) => a.account.id == bank).balance,
          -50000,
        );
      },
    );
  });

  group('in a backup', () {
    test('the limit and the bill day are saved and come back', () async {
      await makeCard();
      await insertTestAccount(db, name: 'Cash');
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      final accounts = (json['accounts']! as List).cast<Map<String, Object?>>();
      expect(accounts.first['creditLimit'], 5000000);
      expect(accounts.first['billDueDay'], 15);
      expect(accounts.last['creditLimit'], isNull);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      final card = (await AccountsRepository(
        other,
      ).getAccounts()).firstWhere((a) => a.name == 'Visa');
      expect(card.type, AccountType.creditCard);
      expect(card.creditLimit, 5000000);
      expect(card.billDueDay, 15);
    });

    test('an older backup without them still restores', () async {
      await insertTestAccount(db, name: 'Cash');
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 3;
      for (final account in (json['accounts']! as List).cast<Map>()) {
        account
          ..remove('creditLimit')
          ..remove('billDueDay');
      }

      final read = BackupData.fromJson(json);

      expect(read.accounts.first.creditLimit, isNull);
      expect(read.accounts.first.billDueDay, isNull);
    });
  });
}
