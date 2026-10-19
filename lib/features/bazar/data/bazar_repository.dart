import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

/// The bazar list and the prices it remembers.
class BazarRepository {
  BazarRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// The list, what is still to buy first.
  Stream<List<ShoppingItem>> watchItems() => _db.bazarDao.watchItems().map(
    (rows) => [for (final row in rows) _toItem(row)],
  );

  /// Remembered prices whose name has [query] in it (the latest ones when it
  /// is empty), the newest first.
  Future<List<PriceSuggestion>> suggestions(String query) async {
    final rows = await _db.bazarDao.suggestions(priceKey(query));
    return [
      for (final row in rows) PriceSuggestion(name: row.name, price: row.price),
    ];
  }

  /// Adds [name] to the list. Without a [price] it takes the one remembered
  /// for that name, if any. Returns the item's id.
  Future<int> addItem(String name, {int quantity = 1, int? price}) async {
    final clean = _validatedName(name);
    _validate(quantity, price);
    final cost = price ?? (await _db.bazarDao.priceFor(priceKey(clean)))?.price;
    return _db.bazarDao.insertItem(
      ShoppingItemsCompanion.insert(
        name: clean,
        quantity: Value(quantity),
        price: Value(cost),
      ),
    );
  }

  /// Changes an item. A price that is set is remembered for next time.
  Future<void> updateItem(
    int id, {
    required String name,
    required int quantity,
    int? price,
  }) async {
    final current = await _db.bazarDao.getItem(id);
    if (current == null) throw ValidationException(tr('Item not found.'));
    final clean = _validatedName(name);
    _validate(quantity, price);
    await _db.bazarDao.updateItem(
      current.copyWith(name: clean, quantity: quantity, price: Value(price)),
    );
    if (price != null) await _remember(clean, price);
  }

  /// Puts back an item that was just removed (for "Undo"), as it was: how
  /// many, the price and whether it was ticked. It goes to the end of the list.
  Future<int> restoreItem(ShoppingItem item) {
    return _db.bazarDao.insertItem(
      ShoppingItemsCompanion.insert(
        name: item.name,
        quantity: Value(item.quantity),
        price: Value(item.price),
        isDone: Value(item.isDone),
      ),
    );
  }

  Future<void> setDone(int id, {required bool done}) async {
    final current = await _db.bazarDao.getItem(id);
    if (current == null) return;
    await _db.bazarDao.updateItem(current.copyWith(isDone: done));
  }

  Future<void> deleteItem(int id) async {
    await _db.bazarDao.deleteItem(id);
  }

  /// Removes the ticked items without making an expense. Returns how many.
  Future<int> removeBought() => _db.bazarDao.deleteDone();

  /// Empties the list. Returns how many items went.
  Future<int> clearList() => _db.bazarDao.deleteAllItems();

  /// The remembered prices, the newest first.
  Stream<List<RememberedPrice>> watchPrices() => _db.bazarDao.watchPrices().map(
    (rows) => [
      for (final row in rows)
        RememberedPrice(
          name: row.name,
          price: row.price,
          updatedAt: row.updatedAt,
        ),
    ],
  );

  /// Remembers [price] for [name]. When [replacing] is the name of a price
  /// already kept, that one is changed (and renamed, if the name differs).
  Future<void> savePrice({
    required String name,
    required int price,
    String? replacing,
  }) async {
    final clean = _validatedName(name);
    if (price < 0) {
      throw ValidationException(tr('The price cannot be negative.'));
    }
    final key = priceKey(clean);
    final old = replacing == null ? null : priceKey(replacing);
    await _db.transaction(() async {
      if (old != null && old != key) {
        if (await _db.bazarDao.priceFor(key) != null) {
          throw ValidationException(
            tr('A price for {name} is already saved.', {'name': clean}),
          );
        }
        await _db.bazarDao.deletePrice(old);
      }
      await _remember(clean, price);
    });
  }

  Future<void> deletePrice(String name) =>
      _db.bazarDao.deletePrice(priceKey(name));

  /// Puts back a price that was just removed (for "Undo"), as it was.
  Future<void> restorePrice(RememberedPrice price) =>
      _db.bazarDao.rememberPrice(
        key: price.key,
        name: price.name,
        price: price.price,
        at: price.updatedAt,
      );

  /// After the shopping was paid for: the prices of the ticked items are
  /// remembered and the ticked items leave the list. Returns how many left.
  Future<int> finishShopping() {
    return _db.transaction(() async {
      final items = await _db.bazarDao.getAllItems();
      for (final item in items) {
        final price = item.price;
        if (item.isDone && price != null) await _remember(item.name, price);
      }
      return _db.bazarDao.deleteDone();
    });
  }

  Future<void> _remember(String name, int price) => _db.bazarDao.rememberPrice(
    key: priceKey(name),
    name: name,
    price: price,
    at: _clock(),
  );

  String _validatedName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) throw ValidationException(tr('Enter a name.'));
    if (clean.length > maxItemNameLength) {
      throw ValidationException(
        tr('The name must be {max} characters or fewer.', {
          'max': maxItemNameLength,
        }),
      );
    }
    return clean;
  }

  void _validate(int quantity, int? price) {
    if (quantity < 1 || quantity > maxItemQuantity) {
      throw ValidationException(
        tr('The quantity must be from 1 to {max}.', {'max': maxItemQuantity}),
      );
    }
    if (price != null && price < 0) {
      throw ValidationException(tr('The price cannot be negative.'));
    }
  }
}

ShoppingItem _toItem(ShoppingItemRow row) => ShoppingItem(
  id: row.id,
  name: row.name,
  quantity: row.quantity,
  price: row.price,
  isDone: row.isDone,
);
