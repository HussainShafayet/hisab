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
