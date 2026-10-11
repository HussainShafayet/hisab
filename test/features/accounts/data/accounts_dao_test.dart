import 'package:drift/drift.dart' show InvalidDataException, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('stores and reads an account, with defaults', () async {
    final id = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'bKash',
        type: AccountType.mobileBanking,
        openingBalance: const Value(1234567),
      ),
    );

    final account = await db.accountsDao.getById(id);

    expect(account, isNotNull);
    expect(account!.name, 'bKash');
    expect(account.type, AccountType.mobileBanking);
    expect(account.openingBalance, 1234567);
    expect(account.includeInTotal, isTrue);
    expect(account.isArchived, isFalse);
    expect(account.createdAt.difference(DateTime.now()).inMinutes.abs(), 0);
  });

  test('getById returns null for an unknown id', () async {
    expect(await db.accountsDao.getById(999), isNull);
  });

  test('an opening balance can be negative', () async {
    final id = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'Card',
        type: AccountType.card,
        openingBalance: const Value(-50000),
      ),
    );

    expect((await db.accountsDao.getById(id))!.openingBalance, -50000);
  });

  test('rejects an empty name', () async {
    expect(
      () => insertTestAccount(db, name: ''),
      throwsA(isA<InvalidDataException>()),
    );
  });

  test('archiving hides an account from the default list only', () async {
    final cash = await insertTestAccount(db, name: 'Cash');
    final bank = await insertTestAccount(db, name: 'Bank');

    await db.accountsDao.setArchived(bank, archived: true);

    expect((await db.accountsDao.getAll()).map((a) => a.id), [cash]);
    expect(
      (await db.accountsDao.getAll(includeArchived: true)).map((a) => a.id),
      [cash, bank],
    );
    expect((await db.accountsDao.getById(bank))!.isArchived, isTrue);
  });

  test('an archived account can be restored', () async {
    final id = await insertTestAccount(db);
    await db.accountsDao.setArchived(id, archived: true);
    await db.accountsDao.setArchived(id, archived: false);

    expect(await db.accountsDao.getAll(), hasLength(1));
  });

  test('updateAccount replaces the row', () async {
    final id = await insertTestAccount(db, name: 'Cash');
    final account = (await db.accountsDao.getById(id))!;

    final updated = await db.accountsDao.updateAccount(
      account.copyWith(name: 'Wallet', includeInTotal: false),
    );

    expect(updated, isTrue);
    final reloaded = (await db.accountsDao.getById(id))!;
    expect(reloaded.name, 'Wallet');
    expect(reloaded.includeInTotal, isFalse);
  });

  test('watchAll emits again after a change', () async {
    final emissions = <List<String>>[];
    final subscription = db.accountsDao.watchAll().listen(
      (accounts) => emissions.add(accounts.map((a) => a.name).toList()),
    );
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await insertTestAccount(db, name: 'Cash');
    await pumpEventQueue();

    expect(emissions, [
      <String>[],
      ['Cash'],
    ]);
  });
}
