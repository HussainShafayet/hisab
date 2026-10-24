import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/domain/year_facts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/features/settings/presentation/providers/income_privacy_providers.dart';
import 'package:hishab/features/settings/presentation/widgets/hidden_income.dart';

/// A year, month by month: for each month the income and the expense as two
/// thin bars, and what was left, with what the year says under them. A tap on
/// a month opens that month.
class MonthByMonthCard extends ConsumerWidget {
  const MonthByMonthCard({
    required this.months,
    required this.now,
    required this.onOpen,
    super.key,
  });

  /// The months of the year, oldest first.
  final List<MonthTotals> months;

  /// Months after this day are not listed.
  final DateTime now;

  final ValueChanged<DateTime> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeHidden = ref.watch(incomeHiddenProvider);
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final shown = [
      for (final month in months)
        if (!month.month.isAfter(now)) month,
    ];
    var peak = 1;
    for (final month in shown) {
      if (!incomeHidden && month.totals.income > peak) {
        peak = month.totals.income;
      }
      if (month.totals.expense > peak) peak = month.totals.expense;
    }
    final facts = yearFacts(months, now: now);

    Widget bar(int poisha, Color color) => LayoutBuilder(
      builder: (context, box) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: 6,
          width: poisha <= 0
              ? 0
              : (box.maxWidth * poisha / peak).clamp(2, box.maxWidth),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );

    return Card(
      key: const ValueKey('month-by-month'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Month by month'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final month in shown)
              InkWell(
                key: ValueKey('month-row-${month.month.month}'),
                onTap: () => onOpen(month.month),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          shortMonthLabel(month.month),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (!incomeHidden) ...[
                              bar(month.totals.income, colors.income),
                              const SizedBox(height: 3),
                            ],
                            bar(month.totals.expense, colors.expense),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: incomeHidden
                              ? const HiddenIncome()
                              : _Net(totals: month.totals),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (facts.activeMonths > 0) ...[
              const Divider(height: 24),
              Text(
                incomeHidden
                    ? tr('Average per month: expense {expense}', {
                        'expense': formatPoisha(facts.averageExpense),
                      })
                    : tr(
                        'Average per month: income {income}, expense {expense}',
                        {
                          'income': formatPoisha(facts.averageIncome),
                          'expense': formatPoisha(facts.averageExpense),
                        },
                      ),
                key: const ValueKey('year-average'),
                style: theme.textTheme.bodyMedium,
              ),
              if (facts.mostSpent != null) ...[
                const SizedBox(height: 4),
                Text(
                  tr('Most spent: {month}, {amount}', {
                    'month': DateFormat('MMMM').format(facts.mostSpent!.month),
                    'amount': formatPoisha(facts.mostSpent!.totals.expense),
                  }),
                  key: const ValueKey('year-most-spent'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (!incomeHidden && facts.mostKept != null) ...[
                const SizedBox(height: 4),
                Text(
                  tr('Most kept: {month}, {amount}', {
                    'month': DateFormat('MMMM').format(facts.mostKept!.month),
                    'amount': formatPoisha(facts.mostKept!.totals.net),
                  }),
                  key: const ValueKey('year-most-kept'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                plural(
                  facts.activeMonths,
                  'Averages are over the 1 month with entries.',
                  'Averages are over the {n} months with entries.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What was left of one month: green with a plus, red with a minus.
class _Net extends StatelessWidget {
  const _Net({required this.totals});

  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    if (totals.income == 0 && totals.expense == 0) {
      return Text(
        '–',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final net = totals.net;
    return Text(
      '${net > 0 ? '+' : ''}${formatPoisha(net)}',
      style: theme.textTheme.bodyMedium?.tabular.copyWith(
        color: net < 0 ? colors.expense : colors.income,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
