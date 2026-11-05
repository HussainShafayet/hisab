import 'dart:math' as math;

import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/insights/domain/habits.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';

/// Gathers the numbers the insights are worked out from.
class InsightsRepository {
  InsightsRepository(AppDatabase db)
    : _reports = ReportsRepository(db),
      _budgets = BudgetsRepository(db),
      _recurring = RecurringRepository(db),
      _transactions = TransactionsRepository(db),
      _debts = DebtsRepository(db);

  final ReportsRepository _reports;
  final BudgetsRepository _budgets;
  final RecurringRepository _recurring;
  final TransactionsRepository _transactions;
  final DebtsRepository _debts;

  /// What is spent on again and again, over the last 30 days up to [now].
  Future<List<Habit>> habits(DateTime now) async {
    final today = dateOnly(now);
    final items = await _transactions.getBetween(
      today.subtract(const Duration(days: habitWindowDays)),
      today.add(const Duration(days: 1)),
    );
    return habitsOf(items, today: today);
  }

  /// The insights as of [now]: this month so far against the same days of last
  /// month, the pace of the budget, and what is coming up.
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

    // The month's entries, for the patterns in them.
    final month = await _transactions.getBetween(
      thisPeriod.start,
      thisPeriod.end,
    );
    final weekday = List.filled(7, 0);
    final spendDays = <DateTime>{};
    BiggestExpense? biggest;
    var smallCount = 0;
    var smallTotal = 0;
    var regret = 0;
    for (final item in month) {
      if (item.isAdjustment || item.type != TransactionType.expense) continue;
      final local = item.date.toLocal();
      weekday[local.weekday % 7] += item.amount;
      spendDays.add(dateOnly(local));
      if (biggest == null || item.amount > biggest.amount) {
        biggest = BiggestExpense(
          id: item.id,
          amount: item.amount,
          label: item.categoryName ?? (item.note.isEmpty ? '' : item.note),
        );
      }
      if (item.amount < smallSpendLimit) {
        smallCount++;
        smallTotal += item.amount;
      }
      if (item.feeling == Feeling.regret) regret += item.amount;
    }

    UpcomingLoan? loan;
    for (final item in await _debts.watchDebts().first) {
      final due = item.debt.dueOn;
      if (item.isSettled || due == null) continue;
      final days = daysBetween(today, due);
      if (days < 0) continue;
      if (loan == null || days < loan.days) {
        loan = UpcomingLoan(
          person: item.debt.person,
          amount: item.remaining,
          days: days,
          lent: item.debt.direction == DebtDirection.lent,
        );
      }
    }

    final totals = await _reports.totals(thisPeriod);
    return buildInsights(
      InsightInput(
        today: today,
        income: totals.income,
        daysSoFar: today.day,
        noSpendDays: today.day - spendDays.length,
        weekdaySpend: weekday,
        biggestExpense: biggest,
        smallSpendCount: smallCount,
        smallSpendTotal: smallTotal,
        regretTotal: regret,
        loan: loan,
        expense: totals.expense,
        expenseLastPeriod: (await _reports.totals(lastPeriod)).expense,
        categories: await _reports.expenseByCategory(thisPeriod),
        categoriesLastPeriod: await _reports.expenseByCategory(lastPeriod),
        budgetLimit: budget?.limit,
        budgetSpent: budget?.spent ?? 0,
        recurring: upcoming,
      ),
      max: 12,
    );
  }
}
