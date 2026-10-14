import 'dart:math' as math;

import 'package:hishab/features/budget/domain/safe_to_spend.dart';

/// What a purchase does to today and to the month.
enum AffordVerdict {
  /// It fits in what can be spent today.
  fitsToday,

  /// There is no budget; the accounts can pay for it.
  fitsBalance,

  /// The month stays inside the budget, but it uses up days of the daily share.
  eatsDays,

  /// It breaks this month's budget.
  overBudget,

  /// It is more than the money in the accounts.
  overBalance,
}

class AffordCheck {
  const AffordCheck({
    required this.verdict,
    required this.amount,
    this.days = 0,
  });

  final AffordVerdict verdict;

  /// What the verdict talks about, in poisha: what is left today (fitsToday),
  /// what is left in the accounts (fitsBalance), the new daily share
  /// (eatsDays), or how far over (overBudget, overBalance).
  final int amount;

  /// For [AffordVerdict.eatsDays]: how many days of the daily share it takes.
  final int days;
}

/// Can [price] (poisha) be afforded? [safe] is null when the month has no
/// budget; [totalBalance] is the money in the accounts that count.
AffordCheck affordCheck({
  required int price,
  required SafeToSpend? safe,
  required int totalBalance,
}) {
  if (price > totalBalance) {
    return AffordCheck(
      verdict: AffordVerdict.overBalance,
      amount: price - math.max(0, totalBalance),
    );
  }
  if (safe == null) {
    return AffordCheck(
      verdict: AffordVerdict.fitsBalance,
      amount: totalBalance - price,
    );
  }
  final after = safe.remaining - price;
  if (after < 0) {
    return AffordCheck(
      verdict: AffordVerdict.overBudget,
      amount: price - math.max(0, safe.remaining),
    );
  }
  if (price <= safe.leftToday) {
    return AffordCheck(
      verdict: AffordVerdict.fitsToday,
      amount: safe.leftToday - price,
    );
  }
  final perDay = safe.perDay;
  return AffordCheck(
    verdict: AffordVerdict.eatsDays,
    amount: after ~/ safe.daysLeft,
    days: perDay <= 0 ? safe.daysLeft : (price + perDay - 1) ~/ perDay,
  );
}
