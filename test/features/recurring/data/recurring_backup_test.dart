import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

Map<String, Object?> content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

Future<AppDatabase> ruleDatabase() async {
  final db = createTestDatabase();
  final cash = await insertTestAccount(db, name: 'Cash');
  final rent = await insertTestCategory(db, name: 'Rent');
  final repo = RecurringRepository(db);
  final id = await repo.createRule(
    title: 'House rent',
    type: TransactionType.expense,
    amount: 1500000,
    accountId: cash,
    categoryId: rent,
    frequency: RecurrenceFrequency.monthly,
    startDate: DateTime(2026, 10, 5),
    endDate: DateTime(2027, 3, 5),
    autoAdd: true,
    remind: false,
  );
  await repo.setPaused(id, paused: true);
  await repo.createRule(
    title: 'Weekly',
    type: TransactionType.expense,
    amount: 5000,
    accountId: cash,
    categoryId: rent,
    frequency: RecurrenceFrequency.weekly,
    startDate: DateTime(2026, 10, 6),
  );
  return db;
}

void main() {
  test('a backup holds the rules, with every setting', () async {
    final db = await ruleDatabase();
    addTearDown(db.close);

    final data = await BackupRepository(db).buildBackup(now);

    expect(data.recurringRules.map((r) => r.title), ['House rent', 'Weekly']);
    final rent = data.recurringRules.first;
    expect(rent.frequency, RecurrenceFrequency.monthly);
    expect(rent.endDate, isNotNull);
    expect(rent.autoAdd, isTrue);
    expect(rent.remind, isFalse);
    expect(rent.isPaused, isTrue);
    expect(data.recurringRules.last.endDate, isNull);
  });

  test('restoring brings the rules back exactly', () async {
    final db = await ruleDatabase();
    addTearDown(db.close);
    final backup = BackupData.decode(
      (await BackupRepository(db).buildBackup(now)).encode(),
    );
    final other = createTestDatabase(seedDefaults: true);
    addTearDown(other.close);

    await BackupRepository(other).restore(backup);

    expect(
      content(await BackupRepository(other).buildBackup(now)),
      content(backup),
    );
    expect((await RecurringRepository(other).getRules()).length, 2);
  });

  test('restoring replaces the rules that were there', () async {
    final db = await ruleDatabase();
    addTearDown(db.close);
    final empty = createTestDatabase();
    addTearDown(empty.close);
    await insertTestAccount(empty, name: 'Bank');

    await BackupRepository(db)
        .restore(await BackupRepository(empty).buildBackup(now));

    expect(await db.recurringDao.getAll(), isEmpty);
  });

  test('an older backup has no rules and is still read', () async {
    final db = await ruleDatabase();
    addTearDown(db.close);
    final json = jsonOf(await BackupRepository(db).buildBackup(now))
      ..['formatVersion'] = 2
      ..remove('recurringRules');

    final data = BackupData.fromJson(json);

    expect(data.recurringRules, isEmpty);
  });

  group('a damaged backup', () {
    Future<void> expectDamaged(
      void Function(Map<String, Object?> json) change,
      String message,
    ) async {
      final db = await ruleDatabase();
      addTearDown(db.close);
      final json = jsonOf(await BackupRepository(db).buildBackup(now));
      change(json);
      expect(() => BackupData.fromJson(json), throwsValidation(message));
    }

    Map<String, Object?> first(Map<String, Object?> json) =>
        (json['recurringRules']! as List).first as Map<String, Object?>;

    test('a rule that points at an account that is not in the file', () async {
      await expectDamaged(
        (j) => first(j)['accountId'] = 999,
        'account that is not in the file',
      );
    });

    test('a rule that points at a category that is not in the file', () async {
      await expectDamaged(
        (j) => first(j)['categoryId'] = 999,
        'category that is not in the file',
      );
    });

    test('two rules with the same id', () async {
      await expectDamaged(
        (j) =>
            ((j['recurringRules']! as List).last
                as Map<String, Object?>)['id'] = first(
              j,
            )['id'],
        'two recurring items have the id',
      );
    });

    test('a rule with a frequency it does not know', () async {
      await expectDamaged((j) => first(j)['frequency'] = 'hourly', 'frequency');
    });

    test('a rule with a missing field', () async {
      await expectDamaged((j) => first(j).remove('title'), 'title');
    });
  });
}
