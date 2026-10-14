import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_format.dart';

/// The big number of an investment (or of all of them): what it has made so
/// far, with the percent, and the sums behind it.
class InvestmentSummary extends StatelessWidget {
  const InvestmentSummary({
    required this.totalReturn,
    required this.roiPercent,
    required this.stats,
    this.keyPrefix = 'investment',
    super.key,
  });

  final int totalReturn;
  final int? roiPercent;

  /// Label and amount pairs, in order, with the key each amount gets.
  final List<InvestmentStat> stats;

  /// Starts the keys of the return and the percent.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final color = totalReturn > 0
        ? colors.income
        : totalReturn < 0
        ? colors.expense
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              totalReturn < 0 ? tr('Loss so far') : tr('Return so far'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatReturn(totalReturn),
                    key: ValueKey('$keyPrefix-return'),
                    style: theme.textTheme.headlineMedium?.tabular.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (roiPercent != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatRoi(roiPercent),
                      key: ValueKey('$keyPrefix-roi'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                for (final stat in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatPoisha(stat.amount),
                        key: ValueKey(stat.key),
                        style: theme.textTheme.titleSmall?.tabular,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InvestmentStat {
  const InvestmentStat({
    required this.label,
    required this.amount,
    required this.key,
  });

  final String label;
  final int amount;
  final String key;
}
