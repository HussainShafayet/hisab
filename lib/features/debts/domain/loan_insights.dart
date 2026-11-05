import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/debts/domain/debt.dart';

/// A loan that falls due soon.
class UpcomingDue {
  const UpcomingDue({required this.item, required this.daysLeft});

  final DebtItem item;

  /// 0 is today.
  final int daysLeft;
}

/// The open loans due from today up to [withinDays] days ahead, the soonest
/// first. Late ones are not here: the list and the summary already show them.
List<UpcomingDue> upcomingDues(
  Iterable<DebtItem> items,
  DateTime today, {
  int withinDays = 30,
  int take = 3,
}) {
  final from = dateOnly(today);
  final result = <UpcomingDue>[];
  for (final item in items) {
    final due = item.debt.dueOn;
    if (item.isSettled || due == null) continue;
    final days = dateOnly(due).difference(from).inDays;
    if (days < 0 || days > withinDays) continue;
    result.add(UpcomingDue(item: item, daysLeft: days));
  }
  result.sort((a, b) {
    final byDays = a.daysLeft.compareTo(b.daysLeft);
    return byDays != 0 ? byDays : a.item.debt.id.compareTo(b.item.debt.id);
  });
  return result.take(take).toList();
}

/// How the loans stand between me and everyone: more to get than to give
/// (positive), more to give (negative), or even (zero). Credit card bills are
/// money to give, so pass what is owed on cards as [cardsOwed].
int netPosition(DebtTotals totals, {int cardsOwed = 0}) =>
    totals.toReceive - totals.toPay - cardsOwed;

/// Paying [remaining] off in equal monthly parts.
class PayoffPlan {
  const PayoffPlan({
    required this.months,
    required this.monthly,
    required this.last,
  });

  final int months;

  /// In poisha: what each of the first [months] - 1 payments is.
  final int monthly;

  /// In poisha: the last payment, which is whatever is left (not above
  /// [monthly]).
  final int last;
}

/// [remaining] spread over [months] months: the same part each month, rounded
/// up, and a last payment that is what is left. Null when there is nothing left
/// or [months] is not above zero.
PayoffPlan? payoffPlan(int remaining, int months) {
  if (remaining <= 0 || months <= 0) return null;
  final monthly = (remaining + months - 1) ~/ months;
  // Rounding up can make the plan finish a month early.
  final needed = (remaining + monthly - 1) ~/ monthly;
  final last = remaining - monthly * (needed - 1);
  return PayoffPlan(months: needed, monthly: monthly, last: last);
}

/// The month a payoff plan that starts next month ends in.
DateTime payoffEnd(PayoffPlan plan, DateTime today) =>
    addMonths(monthStart(today), plan.months);

/// How a list of loans is ordered.
enum LoanSort {
  /// Late ones first, then by due day, then the newest (the usual order).
  due,

  /// The most still to be paid first.
  biggest,

  /// The newest first.
  newest,
}

/// [items] without those that do not match [query] (the person's name or the
/// note, ignoring case), in the order of [sort]. Settled loans always come
/// after the open ones.
List<DebtItem> searchAndSort(
  Iterable<DebtItem> items, {
  required String query,
  required LoanSort sort,
  required DateTime today,
}) {
  final needle = query.trim().toLowerCase();
  final matching = [
    for (final item in items)
      if (needle.isEmpty ||
          item.debt.person.toLowerCase().contains(needle) ||
          item.debt.note.toLowerCase().contains(needle))
        item,
  ];
  switch (sort) {
    case LoanSort.due:
      return sortDebts(matching, today);
    case LoanSort.biggest:
      return matching..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        final byLeft = b.remaining.compareTo(a.remaining);
        return byLeft != 0 ? byLeft : b.debt.id.compareTo(a.debt.id);
      });
    case LoanSort.newest:
      return matching..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.debt.id.compareTo(a.debt.id);
      });
  }
}
