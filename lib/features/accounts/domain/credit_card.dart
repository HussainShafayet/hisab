import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/domain/account.dart';

/// Where a credit card stands. A card's balance is zero or below: spending
/// takes it under zero, and what is below zero is what is owed to the bank.
class CreditCardStatus {
  const CreditCardStatus({required this.account, required this.balance});

  final Account account;

  /// The balance now, in poisha.
  final int balance;

  /// What is owed to the bank, in poisha; zero when nothing is.
  int get owed => balance < 0 ? -balance : 0;

  /// Money paid in beyond what was owed, in poisha.
  int get credit => balance > 0 ? balance : 0;

  /// The limit in poisha, if one was set.
  int? get limit => account.creditLimit;

  /// What can still be spent, in poisha: the limit less what is owed. Below
  /// zero when the card is over its limit. Null without a limit.
  int? get available => limit == null ? null : limit! - owed + credit;

  bool get isOverLimit => limit != null && owed > limit!;

  /// How much of the limit is used, from 0 to 1. Null without a limit.
  double? get usage =>
      limit == null ? null : (owed / limit!).clamp(0.0, 1.0).toDouble();

  /// Something is owed, so there is a bill to pay.
  bool get hasBill => owed > 0;

  /// The next day the bill is due, or null when no day was set.
  DateTime? nextDue(DateTime today) => nextBillDue(account.billDueDay, today);

  /// Days from [today] to the due day, or null when no day was set.
  int? daysUntilDue(DateTime today) {
    final due = nextDue(today);
    return due == null ? null : daysBetween(dateOnly(today), due);
  }
}

/// The open credit cards among [accounts], the ones that owe most first.
List<CreditCardStatus> creditCardsOf(Iterable<AccountWithBalance> accounts) {
  final cards = [
    for (final item in accounts)
      if (item.account.isCreditCard && !item.account.isArchived)
        CreditCardStatus(account: item.account, balance: item.balance),
  ];
  cards.sort((a, b) {
    final byOwed = b.owed.compareTo(a.owed);
    return byOwed != 0
        ? byOwed
        : a.account.name.toLowerCase().compareTo(b.account.name.toLowerCase());
  });
  return cards;
}

/// Everything owed on [cards], in poisha.
int totalOwed(Iterable<CreditCardStatus> cards) =>
    cards.fold(0, (sum, card) => sum + card.owed);

/// The first bill day on or after [today] for a bill due on [dueDay] of every
/// month. In a month that is too short the bill falls on its last day
/// (the 31st becomes the 30th, or the 28th).
DateTime? nextBillDue(int? dueDay, DateTime today) {
  if (dueDay == null) return null;
  final from = dateOnly(today);
  final thisMonth = _billDayIn(from.year, from.month, dueDay);
  return thisMonth.isBefore(from)
      ? _billDayIn(from.year, from.month + 1, dueDay)
      : thisMonth;
}

/// The next [count] bill days on or after [today].
List<DateTime> upcomingBillDues(int? dueDay, DateTime today, {int count = 2}) {
  final days = <DateTime>[];
  var from = today;
  for (var i = 0; i < count; i++) {
    final due = nextBillDue(dueDay, from);
    if (due == null) break;
    days.add(due);
    from = DateTime(due.year, due.month, due.day + 1);
  }
  return days;
}

DateTime _billDayIn(int year, int month, int dueDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, dueDay > lastDay ? lastDay : dueDay);
}
