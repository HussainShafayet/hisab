import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late BazarRepository repo;
  var clock = now;

  setUp(() {
    clock = now;
    db = createTestDatabase();
    repo = BazarRepository(db, clock: () => clock);
  });
  tearDown(() => db.close());

  Future<List<String>> names() async => [
    for (final i in await repo.watchItems().first) i.name,
  ];

  group('adding', () {
    test('keeps the name, one of it, with no price', () async {
      await repo.addItem('  Rice ');

      final item = (await repo.watchItems().first).single;

      expect(item.name, 'Rice');
      expect(item.quantity, 1);
      expect(item.price, isNull);
      expect(item.isDone, isFalse);
    });

    test('needs a name that fits', () async {
      await expectLater(repo.addItem('  '), throwsValidation('name'));
      await expectLater(
        repo.addItem('x' * 61),
        throwsValidation('60 characters'),
      );
    });

    test('needs a sensible quantity and price', () async {
      await expectLater(
        repo.addItem('Rice', quantity: 0),
        throwsValidation('quantity'),
      );
      await expectLater(
        repo.addItem('Rice', price: -1),
        throwsValidation('negative'),
      );
    });

    test('takes the price remembered for that name', () async {
      final id = await repo.addItem('Rice', price: 12000);
      await repo.updateItem(id, name: 'Rice', quantity: 1, price: 12000);

      await repo.addItem('  RICE ');

      final prices = [for (final i in await repo.watchItems().first) i.price];
      expect(prices, [12000, 12000]);
    });

    test('prefers the price given over the one remembered', () async {
      final id = await repo.addItem('Rice');
      await repo.updateItem(id, name: 'Rice', quantity: 1, price: 12000);

      final second = await repo.addItem('Rice', price: 13000);

      final item = (await repo.watchItems().first).firstWhere(
        (i) => i.id == second,
      );
      expect(item.price, 13000);
    });
  });

  group('changing', () {
    test('changes the name, quantity and price', () async {
      final id = await repo.addItem('Rice');

      await repo.updateItem(id, name: 'Polao rice', quantity: 5, price: 14000);

      final item = (await repo.watchItems().first).single;
      expect(item.name, 'Polao rice');
      expect(item.quantity, 5);
      expect(item.price, 14000);
      expect(item.total, 70000);
    });

    test('can lose its price', () async {
      final id = await repo.addItem('Rice', price: 12000);

      await repo.updateItem(id, name: 'Rice', quantity: 1);

      expect((await repo.watchItems().first).single.price, isNull);
    });

    test('cannot change an item that is gone', () async {
      await expectLater(
        repo.updateItem(99, name: 'X', quantity: 1),
        throwsValidation('not found'),
      );
    });

    test('is ticked and unticked', () async {
      final id = await repo.addItem('Rice');

      await repo.setDone(id, done: true);
      expect((await repo.watchItems().first).single.isDone, isTrue);

      await repo.setDone(id, done: false);
      expect((await repo.watchItems().first).single.isDone, isFalse);
    });

    test('can be deleted', () async {
      final a = await repo.addItem('Rice');
      await repo.addItem('Oil');

      await repo.deleteItem(a);

      expect(await names(), ['Oil']);
    });
  });

  group('the list', () {
    test('has what is still to buy first, in the order it was added', () async {
      final rice = await repo.addItem('Rice');
      await repo.addItem('Oil');
      await repo.addItem('Egg');
      await repo.setDone(rice, done: true);

      expect(await names(), ['Oil', 'Egg', 'Rice']);
    });
  });

  group('finishing the shopping', () {
    test('removes what is ticked and keeps the rest', () async {
      final rice = await repo.addItem('Rice', price: 12000);
      await repo.addItem('Oil', price: 15000);
      await repo.setDone(rice, done: true);

      final removed = await repo.finishShopping();

      expect(removed, 1);
      expect(await names(), ['Oil']);
    });

    test('remembers the prices of what was bought', () async {
      final rice = await repo.addItem('Rice', price: 12000);
      await repo.addItem('Oil', price: 15000);
      await repo.setDone(rice, done: true);

      await repo.finishShopping();

      final remembered = await repo.suggestions('');
      expect(remembered.map((s) => s.name), ['Rice']);
      expect(remembered.single.price, 12000);
    });

    test('does nothing when nothing is ticked', () async {
      await repo.addItem('Rice', price: 12000);

      expect(await repo.finishShopping(), 0);
      expect(await names(), ['Rice']);
    });
  });

  group('remembered prices', () {
    test('are found by part of the name, the newest first', () async {
      Future<void> price(String name, int p, DateTime at) async {
        clock = at;
        final id = await repo.addItem(name);
        await repo.updateItem(id, name: name, quantity: 1, price: p);
      }

      await price('Basmati rice', 15000, DateTime(2026, 10, 1));
      await price('Rice flour', 5000, DateTime(2026, 10, 5));
      await price('Oil', 17000, DateTime(2026, 10, 3));

      expect((await repo.suggestions('rice')).map((s) => s.name), [
        'Rice flour',
        'Basmati rice',
      ]);
      expect((await repo.suggestions('')).map((s) => s.name), [
        'Rice flour',
        'Oil',
        'Basmati rice',
      ]);
    });

    test('take a search with % and _ literally', () async {
      final id = await repo.addItem('Rice');
      await repo.updateItem(id, name: 'Rice', quantity: 1, price: 100);

      expect(await repo.suggestions('%'), isEmpty);
      expect(await repo.suggestions('_'), isEmpty);
    });

    test('are replaced by a newer price for the same name', () async {
      final id = await repo.addItem('Rice');
      await repo.updateItem(id, name: 'Rice', quantity: 1, price: 12000);
      await repo.updateItem(id, name: 'RICE', quantity: 1, price: 13000);

      final found = await repo.suggestions('rice');

      expect(found, hasLength(1));
      expect(found.single.price, 13000);
      expect(found.single.name, 'RICE');
    });
  });

  group('backup', () {
    test('keeps the list and the remembered prices', () async {
      final rice = await repo.addItem('Rice', quantity: 2, price: 12000);
      await repo.updateItem(rice, name: 'Rice', quantity: 2, price: 12000);
      await repo.setDone(rice, done: true);
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      final restored = BazarRepository(other);
      final item = (await restored.watchItems().first).single;
      expect(item.name, 'Rice');
      expect(item.quantity, 2);
      expect(item.price, 12000);
      expect(item.isDone, isTrue);
      expect((await restored.suggestions('')).single.price, 12000);
    });

    test('an older backup without a list still restores', () async {
      await repo.addItem('Rice');
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 7;
      json
        ..remove('shoppingItems')
        ..remove('itemPrices');

      final read = BackupData.fromJson(json);

      expect(read.shoppingItems, isEmpty);
      expect(read.itemPrices, isEmpty);
    });
  });
}
