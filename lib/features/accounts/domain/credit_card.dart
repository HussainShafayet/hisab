import 'dart:math' as math;

import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';

/// Where a credit card stands. A card's balance is zero or below: spending
/// takes it under zero, and what is below zero is what is owed to the bank.
class CreditCardStatus {
  const CreditCardStatus({
    required this.account,
    required this.balance,
    this.dollars = CardDollars.none,
  });

  final Account account;

  /// The dollar spending on the card.
  final CardDollars dollars;

  /// The balance now, in poisha.
  final int balance;

  /// What is owed to the bank, in poisha; zero when nothing is.
  int get owed => balance < 0 ? -balance : 0;

  /// Money paid in beyond what was owed, in poisha.
  int get credit => balance > 0 ? balance : 0;

  /// The limit in taka, if one was set. For a card that also has a dollar
  /// limit it is the taka limit alone, as the bank shows it.
  int? get limit => account.creditLimit;

  /// The dollar limit in US cents, if the card has one. A separate limit, in
  /// its own money: dollar spending uses it, not the taka limit.
  int? get usdLimit => account.usdLimit;

  /// The card has a dollar limit as well as (or instead of) a taka one.
  bool get hasDollarLimit => usdLimit != null;

  /// What is owed in dollars, written in taka at the latest dollar rate, in
  /// poisha. Zero when no dollars are owed. Close, not exact: the rate is the
  /// one of the latest dollar expense.
  int get dollarsOwedAsTaka {
    final due = dollars.due;
    return due == 0 ? 0 : (dollars.toPoisha(due) ?? 0);
  }

  /// What is owed in taka alone, in poisha. With a dollar limit the dollars
  /// owed are taken out, since they use the dollar limit; without one all that
  /// is owed uses the taka limit.
  int get takaOwed =>
      hasDollarLimit ? math.max(0, owed - dollarsOwedAsTaka) : owed;

  /// What can still be spent in taka, in poisha: the taka limit less the taka
  /// owed, plus money paid in beyond the bill. Below zero when over the limit.
  /// Null without a taka limit.
  int? get takaLeft => limit == null ? null : limit! - takaOwed + credit;

  /// Dollars still free to spend, in US cents. Below zero when the dollar
  /// limit is passed. Null without a dollar limit.
  int? get usdLeft => usdLimit == null ? null : usdLimit! - dollars.due;

  /// Everything still free, in taka (the dollars at the latest rate), in
  /// poisha. Null without both limits, or while there is no dollar rate yet.
  int? get totalLeft {
    final taka = takaLeft;
    final usd = usdLeft;
    final usdAsTaka = usd == null ? null : dollars.toPoisha(usd);
    return taka == null || usdAsTaka == null ? null : taka + usdAsTaka;
  }

  /// What can still be spent, in poisha. For a card with a taka limit alone it
  /// is the limit less what is owed; with a dollar limit too it is
  /// [totalLeft]. Null without a limit, or when it cannot be worked out.
  int? get available => hasDollarLimit ? totalLeft : takaLeft;

  /// A limit is passed: the taka one, or the dollar one.
  bool get isOverLimit =>
      (takaLeft != null && takaLeft! < 0) || (usdLeft != null && usdLeft! < 0);

  /// How much of the taka limit is used, from 0 to 1. Null without a taka
  /// limit.
  double? get usage =>
      limit == null ? null : (takaOwed / limit!).clamp(0.0, 1.0).toDouble();

  /// Whether the card has anything to show about dollars.
  bool get showsDollars => usdLimit != null || dollars.isUsed;

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
List<CreditCardStatus> creditCardsOf(
  Iterable<AccountWithBalance> accounts, {
  Map<int, CardDollars> dollars = const {},
}) {
  final cards = [
    for (final item in accounts)
      if (item.account.isCreditCard && !item.account.isArchived)
        CreditCardStatus(
          account: item.account,
          balance: item.balance,
          dollars: dollars[item.account.id] ?? CardDollars.none,
        ),
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
