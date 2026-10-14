/// What a line of an investment is.
enum InvestmentEntryKind {
  /// Money put into the business. It leaves the account, but it is not an
  /// expense: the money is still yours, in the business.
  putIn,

  /// Profit received. It counts as income.
  profit,

  /// Part of the money put in, taken back. Not income: it was yours already.
  takeBack,
}

/// Money put into a business or another venture, in poisha.
class Investment {
  const Investment({
    required this.id,
    required this.name,
    required this.note,
    required this.startedOn,
    required this.isClosed,
    this.currentValue,
  });

  final int id;
  final String name;
  final String note;
  final DateTime startedOn;

  /// A closed investment is over: what was not taken back is lost.
  final bool isClosed;

  /// What the money still in it is worth now, as the person last set it. Null
  /// means not set: the money is assumed to be worth what it cost.
  final int? currentValue;
}

/// One line of an investment: money put in, profit received, or money taken
/// back.
class InvestmentEntry {
  const InvestmentEntry({
    required this.id,
    required this.investmentId,
    required this.kind,
    required this.amount,
    required this.date,
    required this.note,
    this.accountId,
  });

  final int id;
  final int investmentId;
  final InvestmentEntryKind kind;

  /// In poisha, above zero.
  final int amount;
  final DateTime date;
  final String note;

  /// The account the money moved through, if it was recorded.
  final int? accountId;
}

/// An investment with its sums, and how it is doing.
class InvestmentItem {
  const InvestmentItem({
    required this.investment,
    this.putIn = 0,
    this.profit = 0,
    this.takenBack = 0,
  });

  final Investment investment;

  /// All the money put in.
  final int putIn;

  /// All the profit received.
  final int profit;

  /// All the money taken back.
  final int takenBack;

  /// The money still in it, at cost: put in, less taken back. Never below zero.
  int get stillIn => putIn > takenBack ? putIn - takenBack : 0;

  /// What the money still in it is worth: nothing once it is closed, else what
  /// the person set, else its cost.
  int get value => investment.isClosed ? 0 : investment.currentValue ?? stillIn;

  /// What it has made so far: everything received and everything still held,
  /// less everything put in. Below zero is a loss.
  int get totalReturn => profit + takenBack + value - putIn;

  /// The return as a whole percent of the money put in, rounded half away from
  /// zero. Null when nothing was put in.
  int? get roiPercent {
    if (putIn <= 0) return null;
    final scaled = totalReturn * 100;
    final half = putIn ~/ 2;
    return scaled >= 0
        ? (scaled + half) ~/ putIn
        : -((-scaled + half) ~/ putIn);
  }

  InvestmentStanding get standing => totalReturn > 0
      ? InvestmentStanding.gain
      : totalReturn < 0
      ? InvestmentStanding.loss
      : InvestmentStanding.even;

  /// How much more can be taken back as money put in: the rest is profit.
  int get canTakeBack => stillIn;
}

enum InvestmentStanding { gain, loss, even }

/// All investments added up, for the screen's summary and Home.
class InvestmentTotals {
  const InvestmentTotals({
    this.putIn = 0,
    this.stillIn = 0,
    this.profit = 0,
    this.value = 0,
    this.totalReturn = 0,
  });

  /// Money put in over all of them.
  final int putIn;

  /// Money still in them, at cost.
  final int stillIn;
  final int profit;

  /// What the money still in them is worth.
  final int value;
  final int totalReturn;

  int? get roiPercent {
    if (putIn <= 0) return null;
    final scaled = totalReturn * 100;
    final half = putIn ~/ 2;
    return scaled >= 0
        ? (scaled + half) ~/ putIn
        : -((-scaled + half) ~/ putIn);
  }
}

InvestmentTotals investmentTotals(Iterable<InvestmentItem> items) {
  var putIn = 0;
  var stillIn = 0;
  var profit = 0;
  var value = 0;
  var totalReturn = 0;
  for (final item in items) {
    putIn += item.putIn;
    stillIn += item.investment.isClosed ? 0 : item.stillIn;
    profit += item.profit;
    value += item.value;
    totalReturn += item.totalReturn;
  }
  return InvestmentTotals(
    putIn: putIn,
    stillIn: stillIn,
    profit: profit,
    value: value,
    totalReturn: totalReturn,
  );
}
