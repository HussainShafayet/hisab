import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/bazar/data/bazar_table.dart';

part 'bazar_dao.g.dart';

@DriftAccessor(tables: [ShoppingItems, ItemPrices])
class BazarDao extends DatabaseAccessor<AppDatabase> with _$BazarDaoMixin {
  BazarDao(super.attachedDatabase);

  /// The list, what is still to buy first, in the order things were added.
  Stream<List<ShoppingItemRow>> watchItems() =>
      (select(shoppingItems)..orderBy([
            (i) => OrderingTerm.asc(i.isDone),
            (i) => OrderingTerm.asc(i.id),
          ]))
          .watch();

  Future<List<ShoppingItemRow>> getAllItems() =>
      (select(shoppingItems)..orderBy([(i) => OrderingTerm.asc(i.id)])).get();

  Future<ShoppingItemRow?> getItem(int id) =>
      (select(shoppingItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<int> insertItem(ShoppingItemsCompanion item) =>
      into(shoppingItems).insert(item);

  Future<bool> updateItem(ShoppingItemRow item) =>
      update(shoppingItems).replace(item);

  Future<int> deleteItem(int id) =>
      (delete(shoppingItems)..where((i) => i.id.equals(id))).go();

  /// Removes every ticked item. Returns how many went.
  Future<int> deleteDone() =>
      (delete(shoppingItems)..where((i) => i.isDone.equals(true))).go();

  /// Removes everything on the list. Returns how many went.
  Future<int> deleteAllItems() => delete(shoppingItems).go();

  /// Every remembered price, the newest first.
  Stream<List<ItemPriceRow>> watchPrices() =>
      (select(itemPrices)..orderBy([
            (p) => OrderingTerm.desc(p.updatedAt),
            (p) => OrderingTerm.desc(p.id),
          ]))
          .watch();

  Future<int> deletePrice(String key) =>
      (delete(itemPrices)..where((p) => p.nameKey.equals(key))).go();

  Future<List<ItemPriceRow>> getAllPrices() =>
      (select(itemPrices)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();

  Future<ItemPriceRow?> priceFor(String key) => (select(
    itemPrices,
  )..where((p) => p.nameKey.equals(key))).getSingleOrNull();

  /// Remembers [price] for [name] (found by [key]), replacing an older one.
  Future<void> rememberPrice({
    required String key,
    required String name,
    required int price,
    required DateTime at,
  }) => into(itemPrices).insert(
    ItemPricesCompanion.insert(
      nameKey: key,
      name: name,
      price: price,
      updatedAt: Value(at),
    ),
    // The name is what is unique, not the id.
    onConflict: DoUpdate(
      (old) => ItemPricesCompanion(
        name: Value(name),
        price: Value(price),
        updatedAt: Value(at),
      ),
      target: [itemPrices.nameKey],
    ),
  );

  /// Remembered prices whose name contains [query] (all of them when it is
  /// empty), the newest first, at most [limit].
  Future<List<ItemPriceRow>> suggestions(String query, {int limit = 8}) {
    final select_ = select(itemPrices)
      ..orderBy([
        (p) => OrderingTerm.desc(p.updatedAt),
        (p) => OrderingTerm.desc(p.id),
      ])
      ..limit(limit);
    if (query.isNotEmpty) {
      select_.where(
        (p) => p.nameKey.like('%${_escape(query)}%', escapeChar: r'\'),
      );
    }
    return select_.get();
  }

  Future<int> deleteAllPrices() => delete(itemPrices).go();

  String _escape(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
