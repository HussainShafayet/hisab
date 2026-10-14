import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/percent.dart';
import 'package:hishab/features/reports/domain/account_total.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/reports/domain/comparison.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/domain/pie_slices.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The heading of a report card.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleSmall);
}

/// Income, expense and balance of the period, with how each changed since the
/// period before.
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({
    required this.totals,
    required this.previousTotals,
    required this.previousLabel,
    this.days = 0,
    super.key,
  });

  /// How many days the period has, for the daily average. 0 leaves it out.
  final int days;

  final PeriodTotals totals;
  final PeriodTotals previousTotals;

  /// Names the period before, e.g. "September 2026".
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;

    return Card(
      key: const ValueKey('report-summary'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Figure(
                  label: tr('Income'),
                  amount: totals.income,
                  color: colors.income,
                ),
                _Figure(
                  label: tr('Expense'),
                  amount: totals.expense,
                  color: colors.expense,
                ),
                _Figure(
                  label: tr('Balance'),
                  amount: totals.net,
                  color: totals.net < 0 ? colors.expense : null,
                ),
              ],
            ),
            const Divider(height: 28),
            _CardTitle(tr('Compared with {period}', {'period': previousLabel})),
            const SizedBox(height: 8),
            ComparisonLine(
              key: const ValueKey('compare-income'),
              label: tr('Income'),
              comparison: Comparison(
                current: totals.income,
                previous: previousTotals.income,
              ),
              higherIsBetter: true,
            ),
            const SizedBox(height: 4),
            ComparisonLine(
              key: const ValueKey('compare-expense'),
              label: tr('Expense'),
              comparison: Comparison(
                current: totals.expense,
                previous: previousTotals.expense,
              ),
              higherIsBetter: false,
            ),
            if (totals.income > 0) ...[
              const SizedBox(height: 8),
              Text(
                (totals.income - totals.expense) >= 0
                    ? tr('Kept {percent}% of income', {
                        'percent':
                            (totals.income - totals.expense) *
                            100 ~/
                            totals.income,
                      })
                    : tr('Spent {percent}% more than income', {
                        'percent':
                            (totals.expense - totals.income) *
                            100 ~/
                            totals.income,
                      }),
                key: const ValueKey('savings-rate'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (days > 0 && totals.expense > 0) ...[
              const SizedBox(height: 4),
              Text(
                tr('Average spending {amount} a day', {
                  'amount': formatPoisha(totals.expense ~/ days),
                }),
                key: const ValueKey('daily-average'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              tr('Transfers and balance corrections are not counted.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatPoisha(amount),
              style: theme.textTheme.titleSmall?.tabular.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Expense  ↓ 12% · ৳350.00": whether a figure went up or down, in green
/// when that is good news and red when it is bad.
class ComparisonLine extends StatelessWidget {
  const ComparisonLine({
    required this.label,
    required this.comparison,
    required this.higherIsBetter,
    super.key,
  });

  final String label;
  final Comparison comparison;

  /// True for income, false for expense.
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final direction = comparison.direction;

    final isGood = (direction == ChangeDirection.up) == higherIsBetter;
    final color = switch (direction) {
      ChangeDirection.up ||
      ChangeDirection.down => isGood ? colors.income : colors.expense,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final String text;
    if (direction == ChangeDirection.none) {
      text = tr('Nothing in either period');
    } else if (direction == ChangeDirection.same) {
      text = tr('No change');
    } else if (comparison.previous == 0) {
      text = tr('New, nothing before');
    } else {
      text =
          '${localizeDigits('${comparison.percent!.abs()}%')} · '
          '${formatPoisha(comparison.difference.abs())}';
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        // A long amount shrinks to fit instead of running off a small phone.
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (direction == ChangeDirection.up)
                  Icon(Icons.arrow_upward, size: 16, color: color)
                else if (direction == ChangeDirection.down)
                  Icon(Icons.arrow_downward, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.tabular.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A donut chart of spending by category, with a legend.
class CategoryPieCard extends StatefulWidget {
  const CategoryPieCard({
    required this.categories,
    this.incomeCategories = const [],
    super.key,
  });

  /// Spending by category, biggest first.
  final List<CategoryTotal> categories;

  /// Income by category, biggest first.
  final List<CategoryTotal> incomeCategories;

  @override
  State<CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<CategoryPieCard> {
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices = buildPieSlices(
      _income ? widget.incomeCategories : widget.categories,
    );
    final total = slices.fold(0, (sum, s) => sum + s.amount);

    return Card(
      key: const ValueKey('category-pie'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              _income ? tr('Income by category') : tr('Spending by category'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('pie-expense'),
                  showCheckmark: false,
                  label: Text(tr('Expense')),
                  selected: !_income,
                  onSelected: (_) => setState(() => _income = false),
                ),
                ChoiceChip(
                  key: const ValueKey('pie-income'),
                  showCheckmark: false,
                  label: Text(tr('Income')),
                  selected: _income,
                  onSelected: (_) => setState(() => _income = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (slices.isEmpty)
              Text(
                _income
                    ? tr('No income in this period.')
                    : tr('No expenses in this period.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 2,
                        centerSpaceRadius: 62,
                        sections: [
                          for (final slice in slices)
                            PieChartSectionData(
                              value: slice.amount.toDouble(),
                              color: Color(slice.color),
                              radius: 34,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _income ? tr('Earned') : tr('Spent'),
                            style: theme.textTheme.labelSmall,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatPoisha(total),
                              key: const ValueKey('pie-total'),
                              style: theme.textTheme.titleSmall?.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final slice in slices)
                _LegendRow(slice: slice, total: total),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.total});

  final PieSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('legend-${slice.categoryId ?? 'others'}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(slice.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              formatPercent(slice.amount, total),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.tabular.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatPoisha(slice.amount),
            style: theme.textTheme.bodyMedium?.tabular,
          ),
        ],
      ),
    );
  }
}

/// Bars of income and expense for the last months.
class IncomeExpenseBarCard extends StatelessWidget {
  const IncomeExpenseBarCard({required this.months, super.key});

  /// Oldest first.
  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final hasData = months.any(
      (m) => m.totals.income > 0 || m.totals.expense > 0,
    );

    // The chart axis uses plain numbers, in taka. Exact amounts are shown from
    // the integer poisha values when a bar is touched.
    BarChartRodData rod(int poisha, Color color) => BarChartRodData(
      toY: poisha / poishaPerTaka,
      color: color,
      width: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    );

    return Card(
      key: const ValueKey('income-expense-chart'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(tr('Income vs expense')),
            const SizedBox(height: 12),
            if (!hasData)
              Text(
                tr('No income or expense in these months.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              shortMonthLabel(months[value.toInt()].month),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rodData, rodIndex) {
                          final totals = months[groupIndex].totals;
                          final isIncome = rodIndex == 0;
                          return BarTooltipItem(
                            '${isIncome ? tr('Income') : tr('Expense')}\n'
                            '${formatPoisha(isIncome ? totals.income : totals.expense)}',
                            TextStyle(
                              color: isIncome ? colors.income : colors.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            rod(months[i].totals.income, colors.income),
                            rod(months[i].totals.expense, colors.expense),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: colors.income, label: tr('Income')),
                  const SizedBox(width: 16),
                  _LegendDot(color: colors.expense, label: tr('Expense')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// The biggest single expenses of the period.
class TopExpensesCard extends StatelessWidget {
  const TopExpensesCard({required this.items, super.key});

  /// Biggest first.
  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('top-expenses'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _CardTitle(tr('Top expenses')),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                tr('No expenses in this period.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in items)
              TransactionTile(
                key: ValueKey('top-${item.id}'),
                item: item,
                showDate: true,
                onTap: () => context.push(AppRoutes.editTransaction(item.id)),
              ),
        ],
      ),
    );
  }
}

/// Income and expense of each account in the period.
class AccountBreakdownCard extends StatelessWidget {
  const AccountBreakdownCard({required this.accounts, super.key});

  /// The busiest first.
  final List<AccountTotal> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;

    return Card(
      key: const ValueKey('account-breakdown'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(tr('By account')),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              Text(
                tr('No income or expense in this period.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final account in accounts)
              Padding(
                key: ValueKey('account-total-${account.accountId}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (account.income > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+${formatPoisha(account.income)}',
                                style: theme.textTheme.bodySmall?.tabular
                                    .copyWith(color: colors.income),
                              ),
                            ),
                          if (account.expense > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatPoisha(-account.expense),
                                style: theme.textTheme.bodySmall?.tabular
                                    .copyWith(color: colors.expense),
                              ),
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
