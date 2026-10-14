import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/metals/data/metals_repository.dart';
import 'package:hishab/features/metals/domain/metals.dart';

import '../../../helpers/fake_rate_service.dart';
import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 15, 9);

void main() {
  late AppDatabase db;
  late MetalsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = MetalsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('adds, changes and deletes a piece', () async {
    final id = await repo.add(
      metal: Metal.gold,
      name: '  Necklace ',
      milligrams: 23328,
      purity: 917,
      cost: 20000000,
    );

    var pieces = await repo.holdings();
    expect(pieces.single.name, 'Necklace');
    expect(pieces.single.cost, 20000000);
    expect(pieces.single.createdAt, now);

    await repo.update(
      id,
      metal: Metal.silver,
      name: 'Anklet',
      milligrams: 5000,
      purity: 925,
    );
    pieces = await repo.holdings();
    expect(pieces.single.metal, Metal.silver);
    expect(pieces.single.cost, isNull);

    await repo.delete(id);
    expect(await repo.holdings(), isEmpty);
  });

  test('refuses a piece that makes no sense', () async {
    Future<void> add({
      String name = 'Ring',
      int mg = 1000,
      int purity = 917,
      int? cost,
    }) => repo.add(
      metal: Metal.gold,
      name: name,
      milligrams: mg,
      purity: purity,
      cost: cost,
    );

    await expectLater(add(name: '  '), throwsA(isA<ValidationException>()));
    await expectLater(add(name: 'x' * 61), throwsA(isA<ValidationException>()));
    await expectLater(add(mg: 0), throwsA(isA<ValidationException>()));
    await expectLater(add(purity: 0), throwsA(isA<ValidationException>()));
    await expectLater(add(purity: 1001), throwsA(isA<ValidationException>()));
    await expectLater(add(cost: -1), throwsA(isA<ValidationException>()));
    expect(await repo.holdings(), isEmpty);
  });

  test('lists gold before silver', () async {
    await repo.add(
      metal: Metal.silver,
      name: 'Plate',
      milligrams: 9000,
      purity: 1000,
    );
    await repo.add(
      metal: Metal.gold,
      name: 'Ring',
      milligrams: 4000,
      purity: 917,
    );

    expect((await repo.holdings()).map((h) => h.name), ['Ring', 'Plate']);
  });

  test('remembers the prices with the time', () async {
    await repo.savePrices(const GramPrices(gold: 1500000));

    final prices = await repo.prices();
    expect(prices.gold, 1500000);
    expect(prices.silver, isNull);
    expect(prices.at, now);
  });

  test('fetches both prices from the rate service', () async {
    // 3110.34768 USD an ounce is 100 USD a gram: 12,000 taka at 120.
    final fetched = await repo.fetchPrices(
      FakeRateService(gold: 3110.34768, silver: 31.1034768),
    );

    expect(fetched.gold, 1200000);
    expect(fetched.silver, 12000);
    expect((await repo.prices()).gold, 1200000);
  });

  test('a failed fetch changes nothing', () async {
    await repo.savePrices(const GramPrices(gold: 5));

    await expectLater(
      repo.fetchPrices(FakeRateService(fails: true)),
      throwsA(isA<RateException>()),
    );
    expect((await repo.prices()).gold, 5);
  });

  group('backup', () {
    test('keeps the pieces', () async {
      await repo.add(
        metal: Metal.gold,
        name: 'Necklace',
        milligrams: 23328,
        purity: 917,
        cost: 20000000,
      );
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      final piece = (await MetalsRepository(other).holdings()).single;
      expect(piece.name, 'Necklace');
      expect(piece.metal, Metal.gold);
      expect(piece.milligrams, 23328);
      expect(piece.purity, 917);
      expect(piece.cost, 20000000);
    });

    test('an older backup without pieces still restores', () async {
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 8;
      json.remove('metalHoldings');

      expect(BackupData.fromJson(json).metalHoldings, isEmpty);
    });

    test('a piece of an unknown metal is refused', () async {
      await repo.add(
        metal: Metal.gold,
        name: 'Ring',
        milligrams: 4000,
        purity: 917,
      );
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      final pieces = (json['metalHoldings']! as List<Object?>)
          .cast<Map<String, Object?>>();
      pieces.first['metal'] = 'copper';

      expect(
        () => BackupData.fromJson(json),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
