import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
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
                      Text(
                        localizeDigits('${progress.percent}%'),
                        style: theme.textTheme.labelLarge?.tabular.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('Spent {spent} of {limit}', {
                      'spent': formatPoisha(progress.spent),
                      'limit': formatPoisha(progress.limit),
                    }),
                    style: theme.textTheme.bodySmall,
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
