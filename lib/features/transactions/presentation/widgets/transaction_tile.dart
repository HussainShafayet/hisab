import 'package:flutter/material.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/transactions/domain/day_groups.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// One row of the transaction list. Income is green with a plus, expense is
/// red with a minus and a transfer is neutral.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.item,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final TransactionItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final isTransfer = item.type == TransactionType.transfer;

    final (amountText, amountColor) = switch (item.type) {
      TransactionType.income => (
        '+${formatPoisha(item.amount)}',
        colors.income,
      ),
      TransactionType.expense => (formatPoisha(-item.amount), colors.expense),
      TransactionType.transfer => (
        formatPoisha(item.amount),
        theme.colorScheme.onSurface,
      ),
    };

    final details = [
      isTransfer
          ? '${item.accountName} → ${item.toAccountName ?? '?'}'
          : item.accountName,
      // A correction is not real income or spending, so it is drawn in the
      // neutral color and says why the day and month totals skip it.
      if (item.isAdjustment)
        'Correction, not counted in totals'
      else if (item.note.isNotEmpty)
        item.note,
    ];

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: isTransfer
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: const Icon(Icons.swap_horiz),
            )
          : CategoryAvatar(
              icon: item.categoryIcon ?? 'category',
              color: item.categoryColor ?? 0xFF9E9E9E,
            ),
      title: Text(isTransfer ? 'Transfer' : item.categoryName ?? 'No category'),
      subtitle: Text(
        details.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // A ListTile fails to lay out when the trailing widget takes the whole
      // row, which a big amount in large text can do. So the amount gets at
      // most 40% of the width and shrinks to fit.
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.4,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            amountText,
            style: theme.textTheme.titleMedium?.tabular.copyWith(
              color: item.isAdjustment
                  ? theme.colorScheme.onSurface
                  : amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The header above the transactions of one day: the date on the left and
/// the day's income and expense on the right.
class DayHeader extends StatelessWidget {
  const DayHeader({required this.group, required this.label, super.key});

  final DayGroup group;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final style = theme.textTheme.labelLarge?.tabular;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // The amounts sit on the right and shrink instead of overflowing
          // when they are big.
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (group.income > 0)
                    Text(
                      '+${formatPoisha(group.income)}',
                      style: style?.copyWith(color: colors.income),
                    ),
                  if (group.income > 0 && group.expense > 0)
                    const SizedBox(width: 12),
                  if (group.expense > 0)
                    Text(
                      formatPoisha(-group.expense),
                      style: style?.copyWith(color: colors.expense),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income, expense and balance of the transactions being listed.
class TransactionSummary extends StatelessWidget {
  const TransactionSummary({
    required this.income,
    required this.expense,
    super.key,
  });

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final colors = context.financeColors;
    final balance = income - expense;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            _SummaryCell(label: 'Income', amount: income, color: colors.income),
            _SummaryCell(
              label: 'Expense',
              amount: expense,
              color: colors.expense,
            ),
            _SummaryCell(
              label: 'Balance',
              amount: balance,
              color: balance < 0 ? colors.expense : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
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
