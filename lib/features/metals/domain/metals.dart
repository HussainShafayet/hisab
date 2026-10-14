import 'package:hishab/core/l10n/translator.dart';

/// The two metals people keep as savings.
enum Metal { gold, silver }

/// One bhori (vori) is 11.664 g; it is 16 ana, and an ana is 6 roti, so a roti
/// is 121.5 mg. Weights are kept in milligrams.
const milligramsPerBhori = 11664;

/// The most a name can be.
const maxHoldingNameLength = 60;

/// The weight of [bhori], [ana] and [roti], in milligrams (a half milligram
/// rounds up).
int milligramsFromBhori({int bhori = 0, int ana = 0, int roti = 0}) =>
    (bhori * 23328 + ana * 1458 + roti * 243 + 1) ~/ 2;

/// A weight written the way a jeweller says it.
class BhoriWeight {
  const BhoriWeight(this.bhori, this.ana, this.roti);

  final int bhori;
  final int ana;
  final int roti;
}

/// [milligrams] in whole bhori, ana and roti, to the nearest roti.
BhoriWeight bhoriWeightOf(int milligrams) {
  final totalRoti = (milligrams * 2 + 121) ~/ 243;
  return BhoriWeight(totalRoti ~/ 96, (totalRoti % 96) ~/ 6, totalRoti % 6);
}

/// "2 bhori 4 ana 3 roti", leaving out what is zero.
String bhoriText(int milligrams) {
  final w = bhoriWeightOf(milligrams);
  final parts = [
    if (w.bhori > 0) tr('{n} bhori', {'n': w.bhori}),
    if (w.ana > 0) tr('{n} ana', {'n': w.ana}),
    if (w.roti > 0) tr('{n} roti', {'n': w.roti}),
  ];
  return parts.isEmpty ? tr('{n} roti', {'n': 0}) : parts.join(' ');
}

/// "25.80 g".
String gramText(int milligrams) =>
    tr('{n} g', {'n': (milligrams / 1000).toStringAsFixed(2)});

/// How pure a piece is, in parts per thousand (24K gold is 1000, 22K is 917).
class Purity {
  const Purity(this.perMille);

  final int perMille;
}

/// The purities offered for [metal], purest first.
List<Purity> puritiesOf(Metal metal) => switch (metal) {
  Metal.gold => const [Purity(1000), Purity(917), Purity(875), Purity(750)],
  Metal.silver => const [Purity(1000), Purity(925)],
};

/// "22K", "Pure silver", "Sterling" or, for anything else, "91.7%".
String purityLabel(Metal metal, int perMille) {
  if (metal == Metal.gold) {
    return switch (perMille) {
      1000 => '24K',
      917 => '22K',
      875 => '21K',
      750 => '18K',
      _ => '${perMille / 10}%',
    };
  }
  return switch (perMille) {
    1000 => tr('Pure silver'),
    925 => tr('Sterling'),
    _ => '${perMille / 10}%',
  };
}

/// The purity the market price of a bhori is quoted for: 22K gold, pure silver.
int quotedPurity(Metal metal) => metal == Metal.gold ? 917 : 1000;

/// What a piece is worth, in poisha, from its [milligrams], its [purity] and
/// the price of one gram of the pure metal in poisha, rounded to the nearest
/// poisha.
int holdingValue({
  required int milligrams,
  required int purity,
  required int gramPrice,
}) => (milligrams * purity * gramPrice + 500000) ~/ 1000000;

/// The price of one gram of the pure metal, from the price of a bhori of the
/// [quotedPurity] kind.
int gramPriceFromBhori(Metal metal, int bhoriPrice) =>
    (bhoriPrice * 1000000 + (milligramsPerBhori * quotedPurity(metal)) ~/ 2) ~/
    (milligramsPerBhori * quotedPurity(metal));

/// The price of a bhori of the [quotedPurity] kind, from one gram of the pure
/// metal.
int bhoriPriceFromGram(Metal metal, int gramPrice) =>
    (gramPrice * milligramsPerBhori * quotedPurity(metal) + 500000) ~/ 1000000;

/// What the person keeps.
class MetalHolding {
  const MetalHolding({
    required this.id,
    required this.metal,
    required this.name,
    required this.milligrams,
    required this.purity,
    required this.createdAt,
    this.cost,
  });

  final int id;
  final Metal metal;
  final String name;
  final int milligrams;

  /// Parts per thousand.
  final int purity;

  /// What it was bought for, in poisha, if known.
  final int? cost;
  final DateTime createdAt;
}

/// The price of one gram of the pure metal, in poisha, and when it was set.
/// A price is null until it is typed or fetched.
class GramPrices {
  const GramPrices({this.gold, this.silver, this.at});

  final int? gold;
  final int? silver;
  final DateTime? at;

  int? of(Metal metal) => metal == Metal.gold ? gold : silver;

  static const _goldKey = 'metals.gold_gram';
  static const _silverKey = 'metals.silver_gram';
  static const _atKey = 'metals.prices_at';

  factory GramPrices.fromMap(Map<String, String> map) {
    int? price(String key) {
      final value = int.tryParse(map[key] ?? '');
      return value == null || value <= 0 ? null : value;
    }

    return GramPrices(
      gold: price(_goldKey),
      silver: price(_silverKey),
      at: DateTime.tryParse(map[_atKey] ?? ''),
    );
  }

  /// The key / value pairs to save. A null value removes the key.
  Map<String, String?> toMap() => {
    _goldKey: gold?.toString(),
    _silverKey: silver?.toString(),
    _atKey: at?.toIso8601String(),
  };

  GramPrices copyWith({
    int? Function()? gold,
    int? Function()? silver,
    DateTime? at,
  }) => GramPrices(
    gold: gold == null ? this.gold : gold(),
    silver: silver == null ? this.silver : silver(),
    at: at ?? this.at,
  );
}

/// What all the pieces of one metal come to.
class MetalTotal {
  const MetalTotal({
    this.milligrams = 0,
    this.pureMilligrams = 0,
    this.value,
    this.count = 0,
  });

  /// The weight of the pieces as they are (with their alloy).
  final int milligrams;

  /// The weight of the pure metal in them.
  final int pureMilligrams;

  /// Worth, in poisha; null while the price of the metal is not known.
  final int? value;
  final int count;
}

class MetalTotals {
  const MetalTotals({required this.gold, required this.silver});

  final MetalTotal gold;
  final MetalTotal silver;

  /// Gold and silver together, counting only a metal whose price is known.
  int get value => (gold.value ?? 0) + (silver.value ?? 0);

  bool get isEmpty => gold.count == 0 && silver.count == 0;

  MetalTotal of(Metal metal) => metal == Metal.gold ? gold : silver;
}

MetalTotals totalsOf(Iterable<MetalHolding> holdings, GramPrices prices) {
  MetalTotal sum(Metal metal) {
    final pieces = holdings.where((h) => h.metal == metal).toList();
    final price = prices.of(metal);
    var milligrams = 0;
    var pure = 0;
    var value = 0;
    for (final h in pieces) {
      milligrams += h.milligrams;
      pure += h.milligrams * h.purity ~/ 1000;
      if (price != null) {
        value += holdingValue(
          milligrams: h.milligrams,
          purity: h.purity,
          gramPrice: price,
        );
      }
    }
    return MetalTotal(
      milligrams: milligrams,
      pureMilligrams: pure,
      value: price == null ? null : value,
      count: pieces.length,
    );
  }

  return MetalTotals(gold: sum(Metal.gold), silver: sum(Metal.silver));
}
