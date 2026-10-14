import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/transactions/data/feeling_queries.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;
  late Basics b;

  setUp(() async {
    db = createTestDatabase();
    repo = TransactionsRepository(db);
    b = await seedBasics(db);
  });
  tearDown(() => db.close());

  Future<int> spend(
    int amount,
    DateTime date, {
    Feeling? feeling,
    TransactionType type = TransactionType.expense,
  }) => repo.addTransaction(
    TransactionInput(
      type: type,
      amount: amount,
      accountId: b.cash,
      categoryId: type == TransactionType.income ? b.salary : b.food,
      date: date,
      feeling: feeling,
    ),
  );

  Future<Feeling?> feelingOf(int id) async =>
      (await db.transactionsDao.getById(id))!.feeling;

  test('an expense keeps how it felt', () async {
    final id = await spend(500, DateTime(2026, 10, 3), feeling: Feeling.regret);
    expect(await feelingOf(id), Feeling.regret);
  });

  test('an income does not keep a feeling', () async {
    final id = await spend(
      500,
      DateTime(2026, 10, 3),
      feeling: Feeling.want,
      type: TransactionType.income,
    );
    expect(await feelingOf(id), isNull);
  });

  test('changing an expense can set and clear the feeling', () async {
    final id = await spend(500, DateTime(2026, 10, 3));
    TransactionInput input(Feeling? f) => TransactionInput(
      type: TransactionType.expense,
      amount: 500,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 3),
      feeling: f,
    );

    await repo.updateTransaction(id, input(Feeling.need));
    expect(await feelingOf(id), Feeling.need);
    await repo.updateTransaction(id, input(null));
    expect(await feelingOf(id), isNull);
  });

  test('totals by feeling of a month, leaving out the unmarked', () async {
    await spend(1000, DateTime(2026, 10, 3), feeling: Feeling.need);
    await spend(300, DateTime(2026, 10, 4), feeling: Feeling.regret);
    await spend(200, DateTime(2026, 10, 9), feeling: Feeling.regret);
    await spend(700, DateTime(2026, 10, 9));
    await spend(900, DateTime(2026, 9, 30), feeling: Feeling.want);

    final totals = await db.expenseByFeeling(
      DateTime(2026, 10),
      DateTime(2026, 11),
    );

    expect(totals, {Feeling.need: 1000, Feeling.regret: 500});
    expect(await db.markedExpenseCount(), 4);
  });

  test('finds the day of the last regret', () async {
    expect(await db.lastRegretDay(), isNull);
    await spend(300, DateTime(2026, 10, 4, 22), feeling: Feeling.regret);
    await spend(300, DateTime(2026, 10, 9, 8), feeling: Feeling.regret);
    await spend(300, DateTime(2026, 10, 10), feeling: Feeling.need);

    expect(await db.lastRegretDay(), DateTime(2026, 10, 9));
  });

  group('backup', () {
    final now = DateTime(2026, 10, 15);

    test('keeps the feeling', () async {
      final id = await spend(
        500,
        DateTime(2026, 10, 3),
        feeling: Feeling.regret,
      );
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      expect(
        (await other.transactionsDao.getById(id))!.feeling,
        Feeling.regret,
      );
    });

    test('an older backup has no feelings', () async {
      await spend(500, DateTime(2026, 10, 3), feeling: Feeling.regret);
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 9;
      for (final t
          in (json['transactions']! as List).cast<Map<String, Object?>>()) {
        t.remove('feeling');
      }

      expect(BackupData.fromJson(json).transactions.single.feeling, isNull);
    });
  });
}
