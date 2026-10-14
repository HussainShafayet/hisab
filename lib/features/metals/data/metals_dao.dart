import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/metals/data/metals_table.dart';

part 'metals_dao.g.dart';

@DriftAccessor(tables: [MetalHoldings])
class MetalsDao extends DatabaseAccessor<AppDatabase> with _$MetalsDaoMixin {
  MetalsDao(super.attachedDatabase);

  /// Gold first, then silver, in the order they were added.
  Stream<List<MetalHoldingRow>> watchAll() => _ordered().watch();

  Future<List<MetalHoldingRow>> getAll() => _ordered().get();

  SimpleSelectStatement<$MetalHoldingsTable, MetalHoldingRow> _ordered() =>
      select(metalHoldings)..orderBy([
        (h) => OrderingTerm.asc(h.metal),
        (h) => OrderingTerm.asc(h.id),
      ]);

  Future<MetalHoldingRow?> getById(int id) =>
      (select(metalHoldings)..where((h) => h.id.equals(id))).getSingleOrNull();

  Future<int> insertHolding(MetalHoldingsCompanion holding) =>
      into(metalHoldings).insert(holding);

  Future<bool> updateHolding(MetalHoldingRow holding) =>
      update(metalHoldings).replace(holding);

  Future<int> deleteHolding(int id) =>
      (delete(metalHoldings)..where((h) => h.id.equals(id))).go();
}
