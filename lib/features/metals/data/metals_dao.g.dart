// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metals_dao.dart';

// ignore_for_file: type=lint
mixin _$MetalsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MetalHoldingsTable get metalHoldings => attachedDatabase.metalHoldings;
  MetalsDaoManager get managers => MetalsDaoManager(this);
}

class MetalsDaoManager {
  final _$MetalsDaoMixin _db;
  MetalsDaoManager(this._db);
  $$MetalHoldingsTableTableManager get metalHoldings =>
      $$MetalHoldingsTableTableManager(_db.attachedDatabase, _db.metalHoldings);
}
