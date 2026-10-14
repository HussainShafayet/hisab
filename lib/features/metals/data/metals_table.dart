import 'package:drift/drift.dart';
import 'package:hishab/features/metals/domain/metals.dart';

/// Gold and silver the person keeps: a necklace, a bangle, a coin.
@DataClassName('MetalHoldingRow')
class MetalHoldings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get metal => textEnum<Metal>()();

  TextColumn get name => text().withLength(min: 1, max: maxHoldingNameLength)();

  /// The weight of the piece as it is, in milligrams.
  IntColumn get milligrams => integer()();

  /// Parts per thousand: 1000 is pure, 917 is 22K gold.
  IntColumn get purity => integer()();

  /// What it was bought for, in poisha, if known.
  IntColumn get cost => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (milligrams > 0)',
    'CHECK (purity BETWEEN 1 AND 1000)',
    'CHECK (cost IS NULL OR cost >= 0)',
  ];
}
