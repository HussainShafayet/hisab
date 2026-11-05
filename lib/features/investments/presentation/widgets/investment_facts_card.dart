import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/domain/investment_facts.dart';
import 'package:intl/intl.dart';

/// How long money has been in, how much of it has come back, the rate a year,
/// when it will all be back at this pace, and the profit of each month.
class InvestmentFactsCard extends StatelessWidget {
  const InvestmentFactsCard({
    required this.item,
    required this.entries,
    required this.today,
    super.key,
  });

  final InvestmentItem item;
  final List<InvestmentEntry> entries;
  final DateTime today;

  /// "Held for 12 days" / "Held for 6 months".
  static String heldText(int days) => days < 60
      ? plural(days, 'Held for 1 day', 'Held for {n} days')
      : plural(days ~/ 30, 'Held for 1 month', 'Held for {n} months');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final lastLine = entries.isEmpty
        ? null
        : entries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final facts = factsOf(item, today: today, lastLine: lastLine);
    final months = profitByMonth(entries, today: today);
    final top = months.fold<int>(0, (a, m) => m.amount > a ? m.amount : a);
    final recovered = (facts.recoveredPercent / 100).clamp(0.0, 1.0);

    return Card(
      key: const ValueKey('investment-facts'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heldText(facts.heldDays),
              key: const ValueKey('facts-held'),
              style: theme.textTheme.titleSmall,
            ),
            if (item.putIn > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('facts-recovered-bar'),
                  value: recovered,
                  minHeight: 8,
                  color: colors.income,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                facts.recoveredPercent >= 100
                    ? tr('All the money put in is back.')
                    : tr('{percent}% of the money put in is back.', {
                        'percent': facts.recoveredPercent,
                      }),
                key: const ValueKey('facts-recovered'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (facts.annualPercent != null) ...[
              const SizedBox(height: 4),
              Text(
                facts.annualPercent! >= 0
                    ? tr('About {percent}% a year at this pace.', {
                        'percent': facts.annualPercent!,
                      })
                    : tr('About {percent}% a year lost at this pace.', {
                        'percent': -facts.annualPercent!,
                      }),
                key: const ValueKey('facts-annual'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (facts.profitPerMonth != null) ...[
              const SizedBox(height: 4),
              Text(
                tr('Profit is about {amount} a month.', {
                  'amount': formatPoisha(facts.profitPerMonth!),
                }),
                key: const ValueKey('facts-per-month'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (facts.paybackMonths != null) ...[
              const SizedBox(height: 4),
              Text(
                plural(
                  facts.paybackMonths!,
                  'All the money is back in about 1 more month.',
                  'All the money is back in about {n} more months.',
                ),
                key: const ValueKey('facts-payback'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (top > 0) ...[
              const SizedBox(height: 16),
              Text(tr('Profit by month'), style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final month in months)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: month.amount == 0
                                      ? 0.02
                                      : (month.amount / top).clamp(0.05, 1.0),
                                  child: Container(
                                    key: ValueKey(
                                      'profit-bar-'
                                      '${DateFormat('yyyy-MM').format(month.month)}',
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: month.amount == 0
                                          ? theme.colorScheme.outlineVariant
                                          : colors.income,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM')
                                  .format(month.month)
                                  .substring(0, 1),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
