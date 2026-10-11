import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Income and expense totals of [items], in poisha. Transfers only move money
/// between accounts, and balance adjustments are corrections, not real income
/// or spending, so neither is counted.
({int income, int expense}) totalsOf(Iterable<TransactionItem> items) {
  var income = 0;
  var expense = 0;
  for (final item in items) {
    if (item.isAdjustment) continue;
    switch (item.type) {
      case TransactionType.income:
        income += item.amount;
      case TransactionType.expense:
        expense += item.amount;
      case TransactionType.transfer:
        break;
    }
  }
  return (income: income, expense: expense);
}

/// The transactions of one local calendar day.
class DayGroup {
  const DayGroup({required this.day, required this.items});

  /// Midnight of the day, local time.
  final DateTime day;
  final List<TransactionItem> items;

  int get income => totalsOf(items).income;
  int get expense => totalsOf(items).expense;
}

/// Groups transactions by local calendar day, newest day first. Within a day
/// the order of [items] is kept.
List<DayGroup> groupByDay(Iterable<TransactionItem> items) {
  final byDay = <DateTime, List<TransactionItem>>{};
  for (final item in items) {
    byDay.putIfAbsent(dateOnly(item.date.toLocal()), () => []).add(item);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in days) DayGroup(day: day, items: byDay[day]!)];
}
