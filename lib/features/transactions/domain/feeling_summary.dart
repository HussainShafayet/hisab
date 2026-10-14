import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';

/// How a month's spending felt, in poisha, and when the last regret was.
class FeelingSummary {
  const FeelingSummary({
    this.need = 0,
    this.want = 0,
    this.regret = 0,
    this.lastRegret,
    this.markedEver = 0,
  });

  factory FeelingSummary.of(
    Map<Feeling, int> totals, {
    DateTime? lastRegret,
    int markedEver = 0,
  }) => FeelingSummary(
    need: totals[Feeling.need] ?? 0,
    want: totals[Feeling.want] ?? 0,
    regret: totals[Feeling.regret] ?? 0,
    lastRegret: lastRegret,
    markedEver: markedEver,
  );

  final int need;
  final int want;
  final int regret;

  /// The local day of the latest regret ever, if there was one.
  final DateTime? lastRegret;

  /// How many expenses were ever marked.
  final int markedEver;

  /// Everything marked this month.
  int get total => need + want + regret;

  /// Nothing was marked this month.
  bool get isEmpty => total == 0;

  /// What part of the marked money was a regret, from 0 to 1.
  double get regretShare => total == 0 ? 0 : regret / total;

  /// Days from the last regret to [today]; null when there never was one.
  int? daysSinceRegret(DateTime today) {
    final last = lastRegret;
    return last == null ? null : daysBetween(dateOnly(last), dateOnly(today));
  }
}

/// What Takka says about the month; [amount] is the regret, as money.
String regretLine(FeelingSummary summary, String amount) {
  if (summary.regret == 0) return tr('No regrets this month. Takka is proud!');
  if (summary.regretShare >= 0.3) {
    return tr('A lot of regret. Sleep on big buys for a day.');
  }
  return tr('{amount} went on things you regret. Sleep on it next time.', {
    'amount': amount,
  });
}
