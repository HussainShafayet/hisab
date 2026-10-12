import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/percent.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_cards.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_progress_bar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

/// The balance of all accounts, big, at the top of Home.
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({required this.balance, super.key});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('total-balance'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.accounts),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total balance', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatPoisha(balance),
                        style: theme.textTheme.headlineMedium?.tabular.copyWith(
                          fontWeight: FontWeight.w600,
                          color: balance < 0
                              ? context.financeColors.expense
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading above a card, like "This month".
class DashboardHeading extends StatelessWidget {
  const DashboardHeading(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleSmall),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The month's budget as a ring: how much is used, what is left, per day.
class BudgetRingCard extends StatelessWidget {
  const BudgetRingCard({
    required this.budget,
    required this.month,
    required this.today,
    super.key,
  });

  /// Null when no overall budget is set for the month.
  final BudgetItem? budget;
  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = budget;

    return Card(
      key: const ValueKey('budget-ring'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: item == null
              ? Row(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No monthly budget',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'Tap to set one',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : _RingContent(item: item, month: month, today: today),
        ),
      ),
    );
  }
}

class _RingContent extends StatelessWidget {
  const _RingContent({
    required this.item,
    required this.month,
    required this.today,
  });

  final BudgetItem item;
  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.progress;
    final color = budgetLevelColor(context, progress.level);
    final perDay = budgetPerDayText(progress, month: month, today: today);

    return Row(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.fraction,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              Text(
                '${progress.percent}%',
                key: const ValueKey('ring-percent'),
                style: theme.textTheme.titleMedium?.tabular.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly budget', style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  budgetRemainingText(progress),
                  key: const ValueKey('ring-remaining'),
                  style: theme.textTheme.titleLarge?.tabular.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Spent ${formatPoisha(progress.spent)} of '
                '${formatPoisha(progress.limit)}',
                style: theme.textTheme.bodySmall,
              ),
              if (perDay != null)
                Text(
                  perDay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What was spent today and this week, side by side.
class SpendingTiles extends StatelessWidget {
  const SpendingTiles({required this.today, required this.week, super.key});

  final int today;
  final int week;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SpendTile(
              key: const ValueKey('spent-today'),
              label: 'Spent today',
              amount: today,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SpendTile(
              key: const ValueKey('spent-week'),
              label: 'Spent this week',
              amount: week,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({required this.label, required this.amount, super.key});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatPoisha(amount),
                style: theme.textTheme.titleMedium?.tabular.copyWith(
                  color: context.financeColors.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The categories with the most spending this month.
class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({
    required this.categories,
    required this.monthExpense,
    super.key,
  });

  final List<CategoryTotal> categories;

  /// All spending of the month, to show each category's share.
  final int monthExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('top-categories'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: categories.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No spending this month yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          CategoryAvatar(
                            icon: category.icon,
                            color: category.color,
                            radius: 16,
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
                                        category.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatPoisha(category.total),
                                      style:
                                          theme.textTheme.titleSmall?.tabular,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: monthExpense <= 0
                                              ? 0
                                              : (category.total / monthExpense)
                                                    .clamp(0, 1),
                                          minHeight: 6,
                                          color: Color(category.color),
                                          backgroundColor: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        formatPercent(
                                          category.total,
                                          monthExpense,
                                        ),
                                        textAlign: TextAlign.end,
                                        style:
                                            theme.textTheme.bodySmall?.tabular,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

/// The latest transactions, with a way to see them all.
class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({required this.items, super.key});

  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('recent-transactions'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No transactions yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.push(AppRoutes.addTransaction),
                    child: const Text('Add transaction'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final item in items)
                  TransactionTile(
                    key: ValueKey('recent-${item.id}'),
                    item: item,
                    onTap: () =>
                        context.push(AppRoutes.editTransaction(item.id)),
                  ),
              ],
            ),
    );
  }
}
