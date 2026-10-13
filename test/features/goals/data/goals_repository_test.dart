import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late GoalsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = GoalsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> makeGoal({
    String name = 'Laptop',
    int target = 8000000,
    DateTime? day,
  }) => repo.createGoal(name: name, target: target, targetDate: day);

  Future<void> put(int goal, int amount, {DateTime? on}) =>
      repo.addEntry(goal, amount: amount, date: on ?? DateTime(2026, 10, 1));

  group('making a goal', () {
    test('keeps its name, target, day and icon', () async {
      final id = await repo.createGoal(
        name: '  Laptop ',
        target: 8000000,
        targetDate: DateTime(2027, 1, 5, 18),
        icon: 'laptop',
      );

      final goal = (await repo.getGoal(id))!;

      expect(goal.goal.name, 'Laptop');
      expect(goal.goal.target, 8000000);
      expect(goal.goal.targetDate, DateTime(2027, 1, 5));
      expect(goal.goal.icon, 'laptop');
      expect(goal.saved, 0);
    });

    test(
      'can be without a day, and an unknown icon becomes the piggy bank',
      () async {
        final id = await repo.createGoal(
          name: 'Eid',
          target: 500000,
          icon: 'nonsense',
        );

        final goal = (await repo.getGoal(id))!;

        expect(goal.goal.targetDate, isNull);
        expect(goal.goal.icon, 'savings');
      },
    );

    test('needs a name and a target above zero', () async {
      await expectLater(
        repo.createGoal(name: '  ', target: 1000),
        throwsValidation('name'),
      );
      await expectLater(
        repo.createGoal(name: 'A', target: 0),
        throwsValidation('target'),
      );
    });

    test('can be changed', () async {
      final id = await makeGoal();

      await repo.updateGoal(id, name: 'Phone', target: 3000000, icon: 'phone');

      final goal = (await repo.getGoal(id))!;
      expect(goal.goal.name, 'Phone');
      expect(goal.goal.target, 3000000);
      expect(goal.goal.icon, 'phone');
    });

    test('cannot be changed once gone', () async {
      await expectLater(
        repo.updateGoal(99, name: 'X', target: 1),
        throwsValidation('not found'),
      );
    });
  });

  group('money in a goal', () {
    test('adds up what was put in and taken out', () async {
      final id = await makeGoal();
      await put(id, 3000000);
      await put(id, 1000000);
      await put(id, -500000);

      expect((await repo.getGoal(id))!.saved, 3500000);
    });

    test('lists the entries newest first', () async {
      final id = await makeGoal();
      await put(id, 1000, on: DateTime(2026, 10, 1));
      await put(id, 2000, on: DateTime(2026, 10, 5));

      final entries = await repo.watchEntries(id).first;

      expect(entries.map((e) => e.amount), [2000, 1000]);
      expect(entries.first.isTakeOut, isFalse);
    });

    test('cannot be nothing', () async {
      final id = await makeGoal();

      await expectLater(put(id, 0), throwsValidation('zero'));
    });

    test('cannot be taken out beyond what is saved', () async {
      final id = await makeGoal();
      await put(id, 1000);

      await expectLater(put(id, -1001), throwsValidation('saved'));
      await put(id, -1000);
      expect((await repo.getGoal(id))!.saved, 0);
    });

    test('goes to a goal that exists', () async {
      await expectLater(put(99, 1000), throwsValidation('not found'));
    });

    test('keeps a note', () async {
      final id = await makeGoal();
      await repo.addEntry(
        id,
        amount: 1000,
        date: DateTime(2026, 10, 1),
        note: ' bonus ',
      );

      expect((await repo.watchEntries(id).first).single.note, 'bonus');
    });

    test('can have an entry removed', () async {
      final id = await makeGoal();
      await put(id, 1000);
      await put(id, 2000);
      final entries = await repo.watchEntries(id).first;

      await repo.deleteEntry(entries.first.id);

      expect((await repo.getGoal(id))!.saved, 1000);
    });

    test('keeps an entry that money was taken out after', () async {
      final id = await makeGoal();
      await put(id, 1000, on: DateTime(2026, 10, 1));
      await put(id, -800, on: DateTime(2026, 10, 2));
      final deposit = (await repo.watchEntries(id).first).last;

      await expectLater(repo.deleteEntry(deposit.id), throwsValidation());
      expect((await repo.getGoal(id))!.saved, 200);
    });
  });

  group('deleting a goal', () {
    test('takes its entries with it', () async {
      final id = await makeGoal();
      await put(id, 1000);

      await repo.deleteGoal(id);

      expect(await repo.getGoal(id), isNull);
      expect(await db.goalsDao.getAllEntries(), isEmpty);
    });

    test('leaves the other goals alone', () async {
      final a = await makeGoal();
      final b = await makeGoal(name: 'Trip');
      await put(a, 1000);
      await put(b, 2000);

      await repo.deleteGoal(a);

      expect((await repo.getGoal(b))!.saved, 2000);
    });
  });

  group('watching', () {
    test('lists every goal with what is saved, oldest first', () async {
      final a = await makeGoal();
      final b = await makeGoal(name: 'Trip');
      await put(b, 700);

      final goals = await repo.watchGoals().first;

      expect(goals.map((g) => g.goal.id), [a, b]);
      expect(goals.map((g) => g.saved), [0, 700]);
    });

    test('follows the data when it changes', () async {
      final id = await makeGoal();
      final saved = repo
          .watchGoals()
          .map((goals) => goals.single.saved)
          .firstWhere((value) => value == 900);

      await put(id, 900);

      expect(await saved, 900);
    });
  });

  group('backup', () {
    test('keeps goals and their entries', () async {
      final id = await makeGoal(day: DateTime(2027, 1, 5));
      await put(id, 1500);
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      final goal = (await GoalsRepository(other).getGoal(id))!;
      expect(goal.goal.name, 'Laptop');
      expect(goal.goal.targetDate, DateTime(2027, 1, 5));
      expect(goal.saved, 1500);
    });

    test('replaces the goals that were there', () async {
      final id = await makeGoal();
      await put(id, 1500);
      final empty = createTestDatabase();
      addTearDown(empty.close);
      final backup = await BackupRepository(empty).buildBackup(now);

      await BackupRepository(db).restore(BackupData.decode(backup.encode()));

      expect(await db.goalsDao.getAllGoals(), isEmpty);
      expect(await db.goalsDao.getAllEntries(), isEmpty);
    });

    test('an older backup without goals still restores', () async {
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 5;
      json
        ..remove('goals')
        ..remove('goalEntries');

      final read = BackupData.fromJson(json);

      expect(read.goals, isEmpty);
      expect(read.goalEntries, isEmpty);
    });

    test('refuses an entry of a goal that is not in the file', () async {
      final id = await makeGoal();
      await put(id, 1500);
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['goals'] = <Object?>[];

      expect(() => BackupData.fromJson(json), throwsValidation('goal'));
    });
  });
}
