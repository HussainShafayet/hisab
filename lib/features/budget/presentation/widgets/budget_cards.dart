import 'package:hishab/features/budget/domain/budget_placement.dart';
import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/domain/budget_insights.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/budget/domain/budget_progress.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_progress_bar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';

/// "৳2,500.00 left", "Nothing left" or "Over by ৳500.00".
String budgetRemainingText(BudgetProgress progress) {
  final remaining = progress.remaining;
  if (remaining > 0) {
    return tr('{amount} left', {'amount': formatPoisha(remaining)});
  }
  if (remaining == 0) return tr('Nothing left');
  return tr('Over by {amount}', {'amount': formatPoisha(-remaining)});
}

/// "৳120.00 per day · 21 days left", or null when it does not apply (the
/// month is over, or nothing is left).
String? budgetPerDayText(
  BudgetProgress progress, {
  required DateTime month,
  required DateTime today,
}) {
  final days = daysLeftInMonth(month, today);
  final perDay = remainingPerDay(
    remaining: progress.remaining,
    month: month,
    today: today,
  );
  if (days == null || perDay == null || perDay == 0) return null;
  final args = {'amount': formatPoisha(perDay), 'days': days};
  return days == 1
      ? tr('{amount} per day · 1 day left', args)
      : tr('{amount} per day · {days} days left', args);
}

/// The overall budget of the month, big, at the top of the screen.
class OverallBudgetCard extends StatelessWidget {
  const OverallBudgetCard({
    required this.item,
    required this.month,
    required this.today,
    required this.onTap,
    super.key,
  });

  final BudgetItem item;
  final DateTime month;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.progress;
    final color = budgetLevelColor(context, progress.level);
    final perDay = budgetPerDayText(progress, month: month, today: today);
    final pace = budgetPace(
      limit: progress.limit,
      spent: progress.spent,
      month: month,
      today: today,
    );
    // Only while the month is going: after it, the total is already known.
    final projected = today.isBefore(addMonths(monthStart(month), 1))
        ? projectedSpend(spent: progress.spent, month: month, today: today)
        : null;

    return Card(
      key: const ValueKey('overall-budget'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Monthly budget'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  budgetRemainingText(progress),
                  key: const ValueKey('overall-remaining'),
                  style: theme.textTheme.headlineSmall?.tabular.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              BudgetProgressBar(progress: progress),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Spent {spent} of {limit}', {
                        'spent': formatPoisha(progress.spent),
                        'limit': formatPoisha(progress.limit),
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    localizeDigits('${progress.percent}%'),
                    style: theme.textTheme.labelLarge?.tabular.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
              if (item.carriedOver > 0) ...[
                const SizedBox(height: 2),
                Text(
                  tr('Includes {amount} left over from last month', {
                    'amount': formatPoisha(item.carriedOver),
                  }),
                  key: const ValueKey('overall-carried'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (pace != null) ...[
                const SizedBox(height: 4),
                Text(
                  switch (pace) {
                    BudgetPace.onTrack => tr('On track for the month'),
                    BudgetPace.fast => tr(
                      'Spending faster than the month goes',
                    ),
                    BudgetPace.slow => tr(
                      'Spending slower than the month goes',
                    ),
                  },
                  key: const ValueKey('overall-pace'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pace == BudgetPace.fast
                        ? context.financeColors.warning
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (projected != null) ...[
                const SizedBox(height: 4),
                Text(
                  projected > progress.limit
                      ? tr(
                          'At this pace you will spend {amount}, {over} over '
                          'the budget',
                          {
                            'amount': formatPoisha(projected),
                            'over': formatPoisha(projected - progress.limit),
                          },
                        )
                      : tr(
                          'At this pace you will spend {amount}, within the '
                          'budget',
                          {'amount': formatPoisha(projected)},
                        ),
                  key: const ValueKey('overall-projection'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: projected > progress.limit
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (perDay != null) ...[
                const SizedBox(height: 4),
                Text(
                  perDay,
                  key: const ValueKey('overall-per-day'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A category's budget: name, how much is used, a bar and what is left.
class CategoryBudgetTile extends StatelessWidget {
  const CategoryBudgetTile({
    required this.item,
    required this.month,
    required this.today,
    required this.onTap,
    this.placement = const BudgetPlacement(),
    this.onShowEntries,
    super.key,
  });

  /// Opens the list of what was spent against this budget.
  final VoidCallback? onShowEntries;

  final BudgetItem item;
  final DateTime month;
  final DateTime today;
  final VoidCallback onTap;

  /// Where the category sits, shown so same-named budgets can be told apart.
  final BudgetPlacement placement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.progress;
    final color = budgetLevelColor(context, progress.level);
    final perDay = budgetPerDayText(progress, month: month, today: today);
    final left = [budgetRemainingText(progress), ?perDay].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryAvatar(
              icon: item.categoryIcon ?? 'category',
              color: item.categoryColor ?? 0xFF9E9E9E,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.categoryName ?? tr('Category'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onShowEntries != null)
                        IconButton(
                          key: ValueKey('budget-entries-${item.categoryId}'),
                          tooltip: tr('See what was spent'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.receipt_long, size: 20),
                          onPressed: onShowEntries,
                        ),
                      Text(
                        localizeDigits('${progress.percent}%'),
                        style: theme.textTheme.labelLarge?.tabular.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  if (placement.parentPath != null)
                    Text(
                      placement.parentPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (placement.insideOver(progress.limit))
                    Text(
                      tr(
                        'The budgets inside add up to {amount}, more than this one',
                        {'amount': formatPoisha(placement.insideLimits)},
                      ),
                      key: ValueKey('budget-inside-over-${item.categoryId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (placement.countedIn != null)
                    Text(
                      tr('Also counted in the {name} budget', {
                        'name': placement.countedIn,
                      }),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    tr('Spent {spent} of {limit}', {
                      'spent': formatPoisha(progress.spent),
                      'limit': formatPoisha(progress.limit),
                    }),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (item.carriedOver > 0)
                    Text(
                      tr('Includes {amount} left over from last month', {
                        'amount': formatPoisha(item.carriedOver),
                      }),
                      key: ValueKey('carried-${item.categoryId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 6),
                  BudgetProgressBar(progress: progress),
                  const SizedBox(height: 4),
                  Text(
                    left,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progress.level == BudgetLevel.over
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How much of the monthly budget the category budgets plan for, and a warning
/// when they ask for more than there is.
class BudgetPlanCard extends StatelessWidget {
  const BudgetPlanCard({required this.allocation, super.key});

  final BudgetAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final share = allocation.limit <= 0
        ? 0.0
        : (allocation.planned / allocation.limit).clamp(0.0, 1.0);
    final over = allocation.over;
    return Card(
      key: const ValueKey('budget-plan'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Planned in categories'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey('plan-bar'),
                value: share,
                minHeight: 8,
                color: over ? colors.expense : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('{planned} of {limit} is planned', {
                'planned': formatPoisha(allocation.planned),
                'limit': formatPoisha(allocation.limit),
              }),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              over
                  ? tr('The categories ask for {amount} more than the month.', {
                      'amount': formatPoisha(-allocation.unplanned),
                    })
                  : tr('{amount} is not planned yet.', {
                      'amount': formatPoisha(allocation.unplanned),
                    }),
              key: const ValueKey('plan-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: over
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spending that no category budget covers, with a button to give the biggest
/// groups a budget.
class UnbudgetedCard extends StatelessWidget {
  const UnbudgetedCard({
    required this.spending,
    required this.onSetBudget,
    super.key,
  });

  final UnbudgetedSpending spending;

  /// Asked to give a top-level category a budget.
  final ValueChanged<int> onSetBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('budget-unbudgeted'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Spent with no budget'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              formatPoisha(spending.total),
              key: const ValueKey('unbudgeted-total'),
              style: theme.textTheme.titleLarge?.tabular,
            ),
            const SizedBox(height: 4),
            for (final group in spending.top)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${group.name} · ${formatPoisha(group.total)}',
                        key: ValueKey('unbudgeted-${group.categoryId}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (group.categoryId != null)
                      TextButton(
                        key: ValueKey('set-budget-${group.categoryId}'),
                        onPressed: () => onSetBudget(group.categoryId!),
                        child: Text(tr('Set budget')),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
