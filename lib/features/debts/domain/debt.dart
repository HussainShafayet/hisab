import 'dart:math' as math;

import 'package:hishab/core/utils/dates.dart';

/// Which way the money went.
enum DebtDirection {
  /// I gave money; the other person owes me ("baki", money to get).
  lent,

  /// I took money; I owe the other person ("dhar", money to give back).
  borrowed,
}

/// Money lent to, or borrowed from, one person, in poisha.
class Debt {
  const Debt({
    required this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.openedOn,
    required this.note,
    this.dueOn,
    this.accountId,
  });

  final int id;
  final String person;
  final DebtDirection direction;

  /// The whole amount lent or borrowed, above zero.
  final int amount;
  final DateTime openedOn;

  /// The day it should be paid back, if one was agreed.
  final DateTime? dueOn;
  final String note;

  /// The account whose balance moved when the money changed hands, if any.
  final int? accountId;
}

/// A part of a debt that was paid back.
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidOn,
    required this.note,
    this.accountId,
  });

  final int id;
  final int debtId;
  final int amount;
  final DateTime paidOn;
  final String note;
  final int? accountId;
}

/// A [Debt] with how much of it has been paid back.
class DebtItem {
  const DebtItem({required this.debt, required this.paid});

  final Debt debt;

  /// The sum of its payments, in poisha.
  final int paid;

  /// What is still to be paid back; never below zero.
  int get remaining => math.max(0, debt.amount - paid);

  bool get isSettled => remaining == 0;

  /// How much is paid back, from 0 to 1.
  double get progress =>
      debt.amount == 0 ? 0 : (paid / debt.amount).clamp(0.0, 1.0);

  /// Late: not settled and the due day is before [today].
  bool isOverdue(DateTime today) {
    final due = debt.dueOn;
    return !isSettled && due != null && dateOnly(due).isBefore(dateOnly(today));
  }

  /// Days from [today] to the due day (negative when late), or null with no
  /// due day.
  int? daysUntilDue(DateTime today) {
    final due = debt.dueOn;
    return due == null ? null : daysBetween(dateOnly(today), dateOnly(due));
  }
}

/// What is still to get and still to give back, over the open debts.
class DebtTotals {
  const DebtTotals({this.toReceive = 0, this.toPay = 0, this.overdueCount = 0});

  /// Left to get back from people I lent to.
  final int toReceive;

  /// Left to give back to people I borrowed from.
  final int toPay;

  /// How many open debts are late.
  final int overdueCount;
}

DebtTotals debtTotals(Iterable<DebtItem> items, DateTime today) {
  var toReceive = 0;
  var toPay = 0;
  var overdue = 0;
  for (final item in items) {
    if (item.isSettled) continue;
    if (item.debt.direction == DebtDirection.lent) {
      toReceive += item.remaining;
    } else {
      toPay += item.remaining;
    }
    if (item.isOverdue(today)) overdue++;
  }
  return DebtTotals(toReceive: toReceive, toPay: toPay, overdueCount: overdue);
}

/// Open debts first (late ones, then by due day, then newest), settled ones
/// after, newest first.
List<DebtItem> sortDebts(Iterable<DebtItem> items, DateTime today) {
  final list = items.toList();
  int rank(DebtItem item) =>
      item.isSettled ? 2 : (item.isOverdue(today) ? 0 : 1);
  list.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    if (!a.isSettled) {
      final dueA = a.debt.dueOn;
      final dueB = b.debt.dueOn;
      if (dueA != null && dueB != null) {
        final byDue = dueA.compareTo(dueB);
        if (byDue != 0) return byDue;
      } else if (dueA != null) {
        return -1;
      } else if (dueB != null) {
        return 1;
      }
    }
    return b.debt.id.compareTo(a.debt.id);
  });
  return list;
}

/// The key two spellings of one name share: trimmed and lower-case, so
/// "Rahim" and " rahim " are the same person.
String personKey(String name) => name.trim().toLowerCase();

/// Every loan with one person: what they owe me, what I owe them, and the
/// difference.
class PersonDebts {
  const PersonDebts({required this.name, required this.items});

  /// The name as it was written most recently.
  final String name;

  /// Open loans first (see [sortDebts]), then the settled ones.
  final List<DebtItem> items;

  Iterable<DebtItem> get _open => items.where((i) => !i.isSettled);

  /// Left to get back from this person, in poisha.
  int get toReceive => _open
      .where((i) => i.debt.direction == DebtDirection.lent)
      .fold(0, (sum, i) => sum + i.remaining);

  /// Left to give back to this person, in poisha.
  int get toPay => _open
      .where((i) => i.debt.direction == DebtDirection.borrowed)
      .fold(0, (sum, i) => sum + i.remaining);

  /// What is left once the two sides are set against each other: above zero
  /// when they owe me, below zero when I owe them.
  int get net => toReceive - toPay;

  bool get isSettled => _open.isEmpty;

  /// How much can be set off: what is owed both ways, whichever is less.
  int get setOffAmount => math.min(toReceive, toPay);

  /// How many open loans with this person are late.
  int overdueCount(DateTime today) =>
      _open.where((i) => i.isOverdue(today)).length;
}

/// The loans grouped by person. People with something open come first (late
/// ones, then the biggest difference), people who are all settled after,
/// by name.
List<PersonDebts> groupByPerson(Iterable<DebtItem> items, DateTime today) {
  final byKey = <String, List<DebtItem>>{};
  for (final item in items) {
    byKey.putIfAbsent(personKey(item.debt.person), () => []).add(item);
  }
  final people = <PersonDebts>[];
  for (final group in byKey.values) {
    // The newest loan has the spelling the person used last.
    final newest = group.reduce((a, b) => a.debt.id > b.debt.id ? a : b);
    people.add(
      PersonDebts(name: newest.debt.person, items: sortDebts(group, today)),
    );
  }
  int rank(PersonDebts p) =>
      p.isSettled ? 2 : (p.overdueCount(today) > 0 ? 0 : 1);
  people.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    if (!a.isSettled) {
      final byNet = b.net.abs().compareTo(a.net.abs());
      if (byNet != 0) return byNet;
    }
    return personKey(a.name).compareTo(personKey(b.name));
  });
  return people;
}

/// The loans that go the given [direction], sorted like [sortDebts].
List<DebtItem> debtsGoing(
  Iterable<DebtItem> items,
  DebtDirection direction,
  DateTime today,
) => sortDebts(items.where((i) => i.debt.direction == direction), today);

/// When a notification should come for an open loan with a due day.
class PlannedDebtReminder {
  const PlannedDebtReminder({
    required this.item,
    required this.day,
    required this.dayBefore,
  });

  final DebtItem item;

  /// The day the notification is shown.
  final DateTime day;

  /// True for the heads-up the day before, false for the due day itself.
  final bool dayBefore;
}

/// The notifications to schedule for loans as of [today]: one on the due day
/// and one the day before, for every open loan whose due day has not passed.
/// A loan that is late already is not reminded again (the list and Home show
/// it).
List<PlannedDebtReminder> upcomingDebtReminders(
  Iterable<DebtItem> items,
  DateTime today,
) {
  final from = dateOnly(today);
  final planned = <PlannedDebtReminder>[];
  for (final item in items) {
    final due = item.debt.dueOn;
    if (item.isSettled || due == null) continue;
    final dueDay = dateOnly(due);
    if (dueDay.isBefore(from)) continue;
    final before = DateTime(dueDay.year, dueDay.month, dueDay.day - 1);
    if (!before.isBefore(from)) {
      planned.add(
        PlannedDebtReminder(item: item, day: before, dayBefore: true),
      );
    }
    planned.add(PlannedDebtReminder(item: item, day: dueDay, dayBefore: false));
  }
  planned.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    return byDay != 0 ? byDay : a.item.debt.id.compareTo(b.item.debt.id);
  });
  return planned;
}

/// A payment that sets a loan off against one going the other way.
class SetOffStep {
  const SetOffStep(this.debtId, this.amount);

  final int debtId;

  /// In poisha, above zero.
  final int amount;
}

/// How to set off what [person] owes me against what I owe them: take
/// [PersonDebts.setOffAmount] off the loans going each way, the earliest due
/// first. Nothing to do (an empty list) when the money goes only one way.
List<SetOffStep> planSetOff(PersonDebts person) {
  final amount = person.setOffAmount;
  if (amount <= 0) return const [];
  final steps = <SetOffStep>[];
  for (final direction in DebtDirection.values) {
    var left = amount;
    for (final item in person.items) {
      if (left == 0) break;
      if (item.isSettled || item.debt.direction != direction) continue;
      final part = math.min(left, item.remaining);
      steps.add(SetOffStep(item.debt.id, part));
      left -= part;
    }
  }
  return steps;
}
