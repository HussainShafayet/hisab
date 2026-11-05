import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/transaction_stats.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// All / Expense / Income / Transfer, each with how many there are, so the list
/// can be narrowed with one tap.
class TypeFilterChips extends StatelessWidget {
  const TypeFilterChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  final TransactionType? selected;

  /// How many transactions of each type the list holds before narrowing by type.
  final Map<TransactionType, int> counts;
  final ValueChanged<TransactionType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    Widget chip(Key key, String label, int count, TransactionType? type) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: key,
            showCheckmark: false,
            label: Text(localizeDigits('$label · $count')),
            selected: selected == type,
            onSelected: (_) => onSelected(type),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          chip(const ValueKey('type-all'), tr('All'), total, null),
          chip(
            const ValueKey('type-expense'),
            tr('Expense'),
            counts[TransactionType.expense] ?? 0,
            TransactionType.expense,
          ),
          chip(
            const ValueKey('type-income'),
            tr('Income'),
            counts[TransactionType.income] ?? 0,
            TransactionType.income,
          ),
          chip(
            const ValueKey('type-transfer'),
            tr('Transfer'),
            counts[TransactionType.transfer] ?? 0,
            TransactionType.transfer,
          ),
        ],
      ),
    );
  }
}

/// A line of facts under the summary: how many entries, what is spent a day,
/// the biggest expense and where most of the money went.
class TransactionStatsRow extends StatelessWidget {
  const TransactionStatsRow({required this.stats, super.key});

  final TransactionStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final biggest = stats.biggestExpense;
    final top = stats.topCategory;

    Widget fact(Key key, IconData icon, String text, {Color? color}) => Chip(
      key: key,
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(text, style: theme.textTheme.labelMedium),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 0,
        children: [
          fact(
            const ValueKey('stat-count'),
            Icons.receipt_long_outlined,
            plural(stats.count, '1 entry', '{n} entries'),
          ),
          if (stats.expensePerDay > 0)
            fact(
              const ValueKey('stat-per-day'),
              Icons.today_outlined,
              tr('{amount} a day', {
                'amount': formatPoisha(stats.expensePerDay),
              }),
              color: colors.expense,
            ),
          if (biggest != null)
            fact(
              const ValueKey('stat-biggest'),
              Icons.trending_up,
              tr('Biggest {amount}', {'amount': formatPoisha(biggest.amount)}),
            ),
          if (top != null)
            fact(
              const ValueKey('stat-top'),
              Icons.pie_chart_outline,
              tr('Most on {name}', {'name': top.name}),
            ),
        ],
      ),
    );
  }
}
