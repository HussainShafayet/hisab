import 'dart:math' as math;

import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';

/// Gathers the numbers the insights are worked out from.
class InsightsRepository {
  InsightsRepository(AppDatabase db)
    : _reports = ReportsRepository(db),
      _budgets = BudgetsRepository(db),
      _debts = DebtsRepository(db),
      _recurring = RecurringRepository(db);

  final ReportsRepository _reports;
  final BudgetsRepository _budgets;
  final DebtsRepository _debts;
  final RecurringRepository _recurring;

  /// The insights as of [now]: this month so far against the same days of last
  /// month, the pace of the budget, loans, and what is coming up.
  Future<List<Insight>> load(DateTime now) async {
    final today = dateOnly(now);
    final monthStartDay = monthStart(today);
    final thisPeriod = (
      start: monthStartDay,
      end: DateTime(today.year, today.month, today.day + 1),
    );
    final lastMonth = addMonths(monthStartDay, -1);
    final lastDays = math.min(today.day, daysInMonth(lastMonth));
    final lastPeriod = (
      start: lastMonth,
      end: DateTime(lastMonth.year, lastMonth.month, lastDays + 1),
    );

    final budget = await _budgets.overallBudget(now);
    final debts = await _debts.watchDebts().first;
    final rules = await _recurring.getRules();

    UpcomingRecurring? upcoming;
    for (final rule in rules) {
      if (!rule.isActive) continue;
      final days = daysBetween(today, rule.nextDue);
      if (days < 0) continue;
      if (upcoming == null || days < upcoming.days) {
        upcoming = UpcomingRecurring(title: rule.title, days: days);
      }
    }

    return buildInsights(
      InsightInput(
        today: today,
        expense: (await _reports.totals(thisPeriod)).expense,
        expenseLastPeriod: (await _reports.totals(lastPeriod)).expense,
        categories: await _reports.expenseByCategory(thisPeriod),
        categoriesLastPeriod: await _reports.expenseByCategory(lastPeriod),
        budgetLimit: budget?.limit,
        budgetSpent: budget?.spent ?? 0,
        loans: debtTotals(debts, today),
        recurring: upcoming,
      ),
    );
  }
}
