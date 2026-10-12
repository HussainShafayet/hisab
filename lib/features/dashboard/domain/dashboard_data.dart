import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';

/// Everything the Home screen shows.
class DashboardData {
  const DashboardData({
    required this.month,
    required this.monthTotals,
    required this.totalBalance,
    required this.overallBudget,
    required this.todayExpense,
    required this.weekExpense,
    required this.topCategories,
    required this.recent,
  });

  /// The first day of the month being shown.
  final DateTime month;

  /// Income and expense of this month.
  final PeriodTotals monthTotals;

  /// The balance of all accounts that count in the total, in poisha.
  final int totalBalance;

  /// This month's overall budget, or null when none is set.
  final BudgetItem? overallBudget;

  /// Spent today and this week (weeks start on Sunday), in poisha.
  final int todayExpense;
  final int weekExpense;

  /// The three categories with the most spending this month.
  final List<CategoryTotal> topCategories;

  /// The latest transactions of any kind, newest first.
  final List<TransactionItem> recent;
}
