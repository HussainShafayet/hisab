import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/challenges/data/challenges_repository.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

Map<String, Object?> content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

/// A database with a no-spend week about a category and a month with a limit
/// on all spending.
Future<AppDatabase> challengedDatabase() async {
  final db = createTestDatabase();
  await insertTestAccount(db, name: 'Cash');
  final rickshaw = await insertTestCategory(db, name: 'Rickshaw');
  final repo = ChallengesRepository(db);
  await repo.create(
    title: 'No rickshaw',
    kind: ChallengeKind.noSpend,
    startDate: DateTime(2026, 10, 11),
    endDate: DateTime(2026, 10, 17),
    categoryId: rickshaw,
    repeats: true,
  );
  await repo.create(
    title: 'Under 5,000',
    kind: ChallengeKind.limit,
    startDate: DateTime(2026, 10),
    endDate: DateTime(2026, 10, 31),
    limit: 500000,
  );
  return db;
}

Future<void> expectDamaged(
  void Function(Map<String, Object?> json) change,
  String message,
) async {
  final db = await challengedDatabase();
  addTearDown(db.close);
  final json = jsonOf(await BackupRepository(db).buildBackup(now));
  change(json);
  expect(() => BackupData.fromJson(json), throwsValidation(message));
}

void main() {
  group('making a backup', () {
    test('holds the challenges', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);

      final data = await BackupRepository(db).buildBackup(now);

      expect(data.challenges.map((c) => c.title), [
        'No rickshaw',
        'Under 5,000',
      ]);
      expect(data.challenges.first.kind, 'noSpend');
      expect(data.challenges.first.categoryId, isNotNull);
      expect(data.challenges.first.limit, 0);
      expect(data.challenges.first.repeats, isTrue);
      expect(data.challenges.last.repeats, isFalse);
      expect(data.challenges.last.kind, 'limit');
      expect(data.challenges.last.categoryId, isNull);
      expect(data.challenges.last.limit, 500000);
    });

    test('is written as the current format version', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);

      final json = jsonOf(await BackupRepository(db).buildBackup(now));

      expect(json['formatVersion'], backupFormatVersion);
      expect(json['challenges'], hasLength(2));
    });

    test('survives being written and read again', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);
      final first = await BackupRepository(db).buildBackup(now);

      final second = BackupData.decode(first.encode());

      expect(content(second), content(first));
    });
  });

  group('restoring', () {
    test('brings the challenges back exactly, into another database', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);
      final backup = BackupData.decode(
        (await BackupRepository(db).buildBackup(now)).encode(),
      );
      final other = createTestDatabase(seedDefaults: true);
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final restored = await BackupRepository(other).buildBackup(now);
      expect(content(restored), content(backup));
      final items = await ChallengesRepository(other).watchChallenges().first;
      // The latest start comes first.
      expect(items.map((i) => i.challenge.title), [
        'No rickshaw',
        'Under 5,000',
      ]);
    });

    test('replaces the challenges that were there', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);
      final empty = createTestDatabase();
      addTearDown(empty.close);
      await insertTestAccount(empty, name: 'Bank');
      final emptyBackup = await BackupRepository(empty).buildBackup(now);

      await BackupRepository(db).restore(emptyBackup);

      expect(await ChallengesRepository(db).watchChallenges().first, isEmpty);
    });

    test('an older file has none, and is read as having none', () async {
      final db = await challengedDatabase();
      addTearDown(db.close);
      final json = jsonOf(await BackupRepository(db).buildBackup(now))
        ..['formatVersion'] = 11
        ..remove('challenges');

      expect(BackupData.fromJson(json).challenges, isEmpty);
    });
  });

  group('a damaged file', () {
    test('has a challenge of a kind that does not exist', () async {
      await expectDamaged(
        (json) =>
            (json['challenges']! as List<Object?>).cast<Map>().first['kind'] =
                'dare',
        'is of "dare", which is not a kind',
      );
    });

    test('has a challenge that ends before it starts', () async {
      await expectDamaged((json) {
        final first = (json['challenges']! as List<Object?>).cast<Map>().first;
        first['endDate'] = '2020-01-01T00:00:00.000Z';
      }, 'has a limit or days that cannot be');
    });

    test('has a challenge about a category that is not in the file', () async {
      await expectDamaged(
        (json) =>
            (json['challenges']! as List<Object?>)
                    .cast<Map>()
                    .first['categoryId'] =
                987,
        'points to a category that is not in the file',
      );
    });

    test('has two challenges with the same id', () async {
      await expectDamaged((json) {
        final list = (json['challenges']! as List<Object?>).cast<Map>();
        list.last['id'] = list.first['id'];
      }, 'challenges');
    });
  });
}
