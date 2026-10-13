import 'dart:math' as math;

/// The dollars on one credit card, in US cents. Dollar spending is recorded
/// as taka (what the bank charges) with the dollars beside it, so the card's
/// balance stays in taka and this only adds the dollar view.
class CardDollars {
  const CardDollars({
    this.spent = 0,
    this.refunded = 0,
    this.settled = 0,
    this.spentThisMonth = 0,
    this.lastRate,
  });

  /// A card with no dollar entries.
  static const none = CardDollars();

  /// Everything spent in dollars on the card.
  final int spent;

  /// Dollar spending that was refunded.
  final int refunded;

  /// Dollar spending cleared by bill payments.
  final int settled;

  /// Spent in dollars in the month being shown.
  final int spentThisMonth;

  /// Taka per dollar on the latest dollar expense, or null when the card has
  /// none. Used to turn a dollar amount into a rough taka amount.
  final double? lastRate;

  /// Dollars still to pay: spent less what was refunded or cleared, never
  /// below zero.
  int get due => math.max(0, spent - refunded - settled);

  /// Whether the card has any dollar entry at all.
  bool get isUsed => spent > 0 || refunded > 0 || settled > 0;

  /// A rough taka value of [cents] at the latest rate, in poisha, or null when
  /// there is no rate yet.
  int? toPoisha(int cents) {
    final rate = lastRate;
    return rate == null ? null : (cents * rate).round();
  }
}
