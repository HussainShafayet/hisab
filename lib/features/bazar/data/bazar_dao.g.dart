// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bazar_dao.dart';

// ignore_for_file: type=lint
mixin _$BazarDaoMixin on DatabaseAccessor<AppDatabase> {
  $ShoppingItemsTable get shoppingItems => attachedDatabase.shoppingItems;
  $ItemPricesTable get itemPrices => attachedDatabase.itemPrices;
  BazarDaoManager get managers => BazarDaoManager(this);
}

class BazarDaoManager {
  final _$BazarDaoMixin _db;
  BazarDaoManager(this._db);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db.attachedDatabase, _db.shoppingItems);
  $$ItemPricesTableTableManager get itemPrices =>
      $$ItemPricesTableTableManager(_db.attachedDatabase, _db.itemPrices);
}
