/// What the nisab (the least wealth zakat is due on) is measured in.
enum NisabBasis { silver, gold }

/// The nisab in hundredths of a gram: 52.5 tola of silver (612.36 g) or 7.5
/// tola of gold (87.48 g).
int nisabHundredthsOfGram(NisabBasis basis) => switch (basis) {
  NisabBasis.silver => 61236,
  NisabBasis.gold => 8748,
};

/// The nisab in poisha, from the price of one gram in poisha. Null without a
/// price.
int? nisabValue(NisabBasis basis, int? gramPrice) {
  if (gramPrice == null || gramPrice <= 0) return null;
  return nisabHundredthsOfGram(basis) * gramPrice ~/ 100;
}

/// The price of one gram in poisha, from a price per troy ounce in US dollars
/// and the taka a dollar costs.
int gramPriceFrom({required double usdPerOunce, required double bdtPerUsd}) =>
    (usdPerOunce * bdtPerUsd / 31.1034768 * 100).round();

/// Zakat is 2.5% of what is held for a year.
const zakatPerMille = 25;

/// What is counted for zakat, all in poisha.
class ZakatInput {
  const ZakatInput({
    required this.accounts,
    this.owedToYou = 0,
    this.otherAssets = 0,
    this.youOwe = 0,
    this.nisab,
  });

  /// Money in the accounts that are counted.
  final int accounts;

  /// Money other people owe you, if you count it.
  final int owedToYou;

  /// Gold, silver and other savings kept outside the accounts.
  final int otherAssets;

  /// Debts to take off: loans you have to pay back and credit card bills.
  final int youOwe;

  /// The nisab in poisha, or null while it is not known.
  final int? nisab;
}

/// The outcome of [calculateZakat].
class ZakatResult {
  const ZakatResult({
    required this.assets,
    required this.liabilities,
    required this.net,
    required this.nisab,
    required this.due,
  });

  /// Everything counted, in poisha.
  final int assets;

  /// What is taken off.
  final int liabilities;

  /// `assets - liabilities`; zero if that is below zero.
  final int net;

  final int? nisab;

  /// The zakat to pay, in poisha; zero below the nisab or while it is unknown.
  final int due;

  /// The nisab is not known yet, so nothing can be said.
  bool get needsNisab => nisab == null;

  /// The wealth reaches the nisab.
  bool get isDue => nisab != null && net >= nisab!;

  /// How far under the nisab the wealth is, or null at or above it.
  int? get shortOfNisab => nisab != null && net < nisab! ? nisab! - net : null;
}

ZakatResult calculateZakat(ZakatInput input) {
  final assets = input.accounts + input.owedToYou + input.otherAssets;
  final net = assets - input.youOwe < 0 ? 0 : assets - input.youOwe;
  final nisab = input.nisab;
  final isDue = nisab != null && net >= nisab && net > 0;
  return ZakatResult(
    assets: assets,
    liabilities: input.youOwe,
    net: net,
    nisab: nisab,
    // Rounded up to the next poisha, so it is never short.
    due: isDue ? (net * zakatPerMille + 999) ~/ 1000 : 0,
  );
}

/// The next time the yearly zakat day comes, from [today]: [month]/[day] of
/// this year if that is today or later, else of next year. 29 February falls on
/// 28 February in other years.
DateTime nextZakatDay(int month, int day, DateTime today) {
  DateTime inYear(int year) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > last ? last : day);
  }

  final from = DateTime(today.year, today.month, today.day);
  final thisYear = inYear(today.year);
  return thisYear.isBefore(from) ? inYear(today.year + 1) : thisYear;
}
