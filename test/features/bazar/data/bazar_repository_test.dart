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

  group('taking things off the list', () {
    test('puts a removed item back as it was, ticked or not', () async {
      final id = await repo.addItem('Rice', quantity: 2, price: 12000);
      await repo.setDone(id, done: true);
      final item = (await repo.watchItems().first).single;
      await repo.deleteItem(id);
      expect(await names(), isEmpty);

      await repo.restoreItem(item);

      final back = (await repo.watchItems().first).single;
      expect(back.name, 'Rice');
      expect(back.quantity, 2);
      expect(back.price, 12000);
      expect(back.isDone, isTrue);
    });

    test('removes the bought items and keeps the rest', () async {
      final rice = await repo.addItem('Rice');
      await repo.addItem('Oil');
      await repo.setDone(rice, done: true);

      final removed = await repo.removeBought();

      expect(removed, 1);
      expect(await names(), ['Oil']);
    });

    test('clears the whole list', () async {
      await repo.addItem('Rice');
      final oil = await repo.addItem('Oil');
      await repo.setDone(oil, done: true);

      expect(await repo.clearList(), 2);
      expect(await names(), isEmpty);
    });

    test('clearing the list keeps the remembered prices', () async {
      await repo.addItem('Rice', price: 12000);
      final rice = (await repo.watchItems().first).single;
      await repo.updateItem(rice.id, name: 'Rice', quantity: 1, price: 12000);

      await repo.clearList();

      expect((await repo.suggestions('')).single.name, 'Rice');
    });
  });

  group('remembered prices', () {
    Future<List<String>> pricesOf() async => [
      for (final p in await repo.watchPrices().first) '${p.name} ${p.price}',
    ];

    test('are listed, the newest first', () async {
      await repo.savePrice(name: 'Rice', price: 12000);
      clock = now.add(const Duration(days: 1));
      await repo.savePrice(name: 'Oil', price: 18000);

      expect(await pricesOf(), ['Oil 18000', 'Rice 12000']);
    });

    test('can be added by hand', () async {
      await repo.savePrice(name: '  Green Chilli ', price: 4000);

      final price = (await repo.watchPrices().first).single;
      expect(price.name, 'Green Chilli');
      expect(price.key, 'green chilli');
      // And the list uses it.
      await repo.addItem('green chilli');
      expect((await repo.watchItems().first).single.price, 4000);
    });

    test('can be changed', () async {
      await repo.savePrice(name: 'Rice', price: 12000);

      await repo.savePrice(name: 'Rice', price: 13500, replacing: 'Rice');

      expect(await pricesOf(), ['Rice 13500']);
    });

    test('can be renamed, and the old name goes', () async {
      await repo.savePrice(name: 'Rice', price: 12000);

      await repo.savePrice(
        name: 'Miniket rice',
        price: 12000,
        replacing: 'Rice',
      );

      expect(await pricesOf(), ['Miniket rice 12000']);
    });

    test('cannot be renamed to a name that has a price already', () async {
      await repo.savePrice(name: 'Rice', price: 12000);
      await repo.savePrice(name: 'Oil', price: 18000);

      await expectLater(
        repo.savePrice(name: 'oil', price: 100, replacing: 'Rice'),
        throwsValidation('already saved'),
      );

      expect(await pricesOf(), unorderedEquals(['Rice 12000', 'Oil 18000']));
    });

    test('need a name and a price that is not negative', () async {
      await expectLater(
        repo.savePrice(name: '  ', price: 100),
        throwsValidation('name'),
      );
      await expectLater(
        repo.savePrice(name: 'Rice', price: -1),
        throwsValidation('negative'),
      );
    });

    test('can be removed and put back as they were', () async {
      await repo.savePrice(name: 'Rice', price: 12000);
      final price = (await repo.watchPrices().first).single;

      await repo.deletePrice('RICE');
      expect(await pricesOf(), isEmpty);
      await repo.restorePrice(price);

      final back = (await repo.watchPrices().first).single;
      expect(back.name, 'Rice');
      expect(back.price, 12000);
      expect(back.updatedAt, price.updatedAt);
    });
  });
}
