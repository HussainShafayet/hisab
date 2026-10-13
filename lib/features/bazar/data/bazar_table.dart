import 'package:drift/drift.dart';

/// What is on the bazar (shopping) list.
@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// How many; the price below is for one.
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// The price of one, in poisha, if known.
  IntColumn get price => integer().nullable()();

  /// Ticked: bought.
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (quantity > 0)',
    'CHECK (price IS NULL OR price >= 0)',
  ];
}

/// The last price paid for each thing, by its name in lower case, so the next
/// time it is added the price is already there.
@DataClassName('ItemPriceRow')
class ItemPrices extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The name, lower case and trimmed.
  TextColumn get nameKey => text().unique()();

  /// The name as it was last written.
  TextColumn get name => text()();

  /// The price of one, in poisha.
  IntColumn get price => integer()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
