import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/metals/domain/metals.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';

/// The gold and silver the person keeps, and the price of a gram that values
/// them.
class MetalsRepository {
  MetalsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<MetalHolding>> watchHoldings() => _db.metalsDao.watchAll().map(
    (rows) => [for (final row in rows) _toHolding(row)],
  );

  Future<List<MetalHolding>> holdings() async => [
    for (final row in await _db.metalsDao.getAll()) _toHolding(row),
  ];

  Future<int> add({
    required Metal metal,
    required String name,
    required int milligrams,
    required int purity,
    int? cost,
  }) async {
    final clean = _validated(name, milligrams, purity, cost);
    return _db.metalsDao.insertHolding(
      MetalHoldingsCompanion.insert(
        metal: metal,
        name: clean,
        milligrams: milligrams,
        purity: purity,
        cost: Value(cost),
        createdAt: Value(_clock()),
      ),
    );
  }

  Future<void> update(
    int id, {
    required Metal metal,
    required String name,
    required int milligrams,
    required int purity,
    int? cost,
  }) async {
    final current = await _db.metalsDao.getById(id);
    if (current == null) throw ValidationException(tr('Piece not found.'));
    final clean = _validated(name, milligrams, purity, cost);
    await _db.metalsDao.updateHolding(
      current.copyWith(
        metal: metal,
        name: clean,
        milligrams: milligrams,
        purity: purity,
        cost: Value(cost),
      ),
    );
  }

  Future<void> delete(int id) async {
    await _db.metalsDao.deleteHolding(id);
  }

  String _validated(String name, int milligrams, int purity, int? cost) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ValidationException(tr('Give the piece a name, like "Necklace".'));
    }
    if (clean.length > maxHoldingNameLength) {
      throw ValidationException(
        tr('The name can be at most {n} letters.', {'n': maxHoldingNameLength}),
      );
    }
    if (milligrams <= 0) {
      throw ValidationException(tr('Enter the weight of the piece.'));
    }
    if (purity < 1 || purity > 1000) {
      throw ValidationException(tr('Choose how pure it is.'));
    }
    if (cost != null && cost < 0) {
      throw ValidationException(tr('The price paid cannot be negative.'));
    }
    return clean;
  }

  // The prices of a gram.

  Stream<GramPrices> watchPrices() =>
      _db.settingsDao.watchAll().map(GramPrices.fromMap);

  Future<GramPrices> prices() async =>
      GramPrices.fromMap(await _db.settingsDao.getAll());

  /// Remembers [prices], stamped with now.
  Future<void> savePrices(GramPrices prices) {
    final stamped = prices.copyWith(at: _clock());
    return _db.transaction(() async {
      for (final entry in stamped.toMap().entries) {
        await _db.settingsDao.put(entry.key, entry.value);
      }
    });
  }

  /// Fetches today's market prices of both metals, remembers them and returns
  /// them. Throws a [RateException] when they cannot be had.
  Future<GramPrices> fetchPrices(RateService service) async {
    final rate = await service.usdToBdt();
    final spot = await service.metals();
    final fetched = GramPrices(
      gold: gramPriceFrom(usdPerOunce: spot.goldPerOunce, bdtPerUsd: rate),
      silver: gramPriceFrom(usdPerOunce: spot.silverPerOunce, bdtPerUsd: rate),
    );
    await savePrices(fetched);
    return fetched.copyWith(at: _clock());
  }

  MetalHolding _toHolding(MetalHoldingRow row) => MetalHolding(
    id: row.id,
    metal: row.metal,
    name: row.name,
    milligrams: row.milligrams,
    purity: row.purity,
    cost: row.cost,
    createdAt: row.createdAt,
  );
}
