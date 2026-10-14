import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';
import 'package:hishab/features/transactions/presentation/providers/feeling_providers.dart';

/// On Home: how this month's spending felt, from the expenses marked Needed,
/// Wanted or Regret, and what Takka thinks of it. Not shown until something
/// is marked this month.
class RegretMeterCard extends ConsumerWidget {
  const RegretMeterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(feelingSummaryProvider).value;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final today = ref.read(clockProvider)();
    final since = summary.daysSinceRegret(today);

    Widget legend(Color color, String label, int amount) => Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPoisha(amount),
                    style: theme.textTheme.bodyMedium?.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final needColor = theme.colorScheme.primary;
    final wantColor = theme.colorScheme.tertiary;
    final regretColor = colors.expense;
    Widget part(Color color, int amount) => amount == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: amount,
            child: ColoredBox(color: color, child: const SizedBox(height: 10)),
          );

    return Card(
      key: const ValueKey('regret-meter'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('How your spending felt'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  part(needColor, summary.need),
                  part(wantColor, summary.want),
                  part(regretColor, summary.regret),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                legend(needColor, tr('Needed'), summary.need),
                legend(wantColor, tr('Wanted'), summary.want),
                legend(regretColor, tr('Regret'), summary.regret),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              regretLine(summary, formatPoisha(summary.regret)),
              key: const ValueKey('regret-line'),
              style: theme.textTheme.bodyMedium,
            ),
            if (since != null && since > 0)
              Text(
                tr('{n} days since your last regret.', {'n': since}),
                key: const ValueKey('regret-since'),
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
