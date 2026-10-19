/// One thing on the bazar list.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isDone,
    this.price,
  });

  final int id;
  final String name;

  /// How many, at least 1.
  final int quantity;

  /// The price of one, in poisha, if known.
  final int? price;

  /// Ticked: bought.
  final bool isDone;

  /// What the line costs, in poisha; zero without a price.
  int get total => (price ?? 0) * quantity;
}

/// A price remembered for something bought before.
class PriceSuggestion {
  const PriceSuggestion({required this.name, required this.price});

  final String name;

  /// The price of one, in poisha.
  final int price;
}

/// A price kept for next time, as the Remembered prices screen shows it.
class RememberedPrice {
  const RememberedPrice({
    required this.name,
    required this.price,
    required this.updatedAt,
  });

  final String name;

  /// The price of one, in poisha.
  final int price;

  /// When it was last set.
  final DateTime updatedAt;

  /// What finds it again: the name, trimmed and in lower case.
  String get key => priceKey(name);
}

/// What the list adds up to.
class ShoppingTotals {
  const ShoppingTotals({
    required this.estimated,
    required this.ticked,
    required this.tickedCount,
    required this.withoutPrice,
  });

  /// Everything on the list, in poisha.
  final int estimated;

  /// What is ticked, in poisha.
  final int ticked;
  final int tickedCount;

  /// How many items have no price, so are not in the totals.
  final int withoutPrice;
}

ShoppingTotals totalsOf(Iterable<ShoppingItem> items) {
  var estimated = 0;
  var ticked = 0;
  var tickedCount = 0;
  var withoutPrice = 0;
  for (final item in items) {
    estimated += item.total;
    if (item.isDone) {
      ticked += item.total;
      tickedCount++;
    }
    if (item.price == null) withoutPrice++;
  }
  return ShoppingTotals(
    estimated: estimated,
    ticked: ticked,
    tickedCount: tickedCount,
    withoutPrice: withoutPrice,
  );
}

const maxItemNameLength = 60;
const maxItemQuantity = 9999;

/// The name used to find a remembered price: trimmed, in lower case, with the
/// spaces inside squeezed to one.
String priceKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The note for the expense made from the ticked [items]: "Bazar: rice, oil".
/// Cut to [maxLength] characters.
String bazarNote(Iterable<ShoppingItem> items, {int maxLength = 500}) {
  final text = 'Bazar: ${items.map((i) => i.name).join(', ')}';
  return text.length <= maxLength
      ? text
      : '${text.substring(0, maxLength - 1)}…';
}
