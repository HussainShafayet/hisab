import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/settings/presentation/providers/income_privacy_providers.dart';
import 'package:hishab/features/settings/presentation/widgets/hidden_income.dart';
import 'package:hishab/features/transactions/domain/day_groups.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// One row of the transaction list. Income is green with a plus, expense is
/// red with a minus and a transfer is neutral.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    required this.item,
    this.onTap,
    this.onLongPress,
    this.showDate = false,
    this.selected = false,
    super.key,
  });

  /// Put the date before the account, for lists that are not grouped by day.
  final bool showDate;

  final TransactionItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The row is picked, while several are being chosen: a tick takes the
  /// place of the category's picture and the row is tinted.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeHidden = ref.watch(incomeHiddenProvider);
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
      if (showDate) DateFormat('d MMM').format(item.date),
      isTransfer
          ? '${item.accountName} → ${item.toAccountName ?? '?'}'
          : item.accountName,
      if (item.usdAmount != null) formatUsd(item.usdAmount!),
      if (item.tagName != null) '#${item.tagName}',
      if (item.feeling == Feeling.regret) tr('Regret'),
      // A correction is not real income or spending, so it is drawn in the
      // neutral color and says why the day and month totals skip it.
      if (item.isAdjustment)
        (item.note.isEmpty || item.note == balanceAdjustmentNote)
            ? tr('Balance fix, not in your totals')
            : tr('{note} · not in your totals', {'note': item.note})
      else if (item.note.isNotEmpty)
        item.note,
    ];

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
      leading: selected
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.check),
            )
          : isTransfer
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: const Icon(Icons.swap_horiz),
            )
          : CategoryAvatar(
              icon: item.categoryIcon ?? 'category',
              color: item.categoryColor ?? 0xFF9E9E9E,
            ),
      title: Text(
        isTransfer ? tr('Transfer') : item.categoryName ?? tr('No category'),
      ),
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
          child: () {
            final style = theme.textTheme.titleMedium?.tabular.copyWith(
              color: item.isAdjustment
                  ? theme.colorScheme.onSurface
                  : amountColor,
              fontWeight: FontWeight.w600,
            );
            // Income is a secret while it is hidden; a balance fix is not.
            if (incomeHidden &&
                item.type == TransactionType.income &&
                !item.isAdjustment) {
              return HiddenIncome(style: style);
            }
            return Text(amountText, style: style);
          }(),
        ),
      ),
    );
  }
}

/// The header above the transactions of one day: the date on the left and
/// the day's income and expense on the right.
class DayHeader extends ConsumerWidget {
  const DayHeader({required this.group, required this.label, super.key});

  final DayGroup group;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeHidden = ref.watch(incomeHiddenProvider);
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
                    incomeHidden
                        ? HiddenIncome(
                            style: style?.copyWith(color: colors.income),
                          )
                        : Text(
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
class TransactionSummary extends ConsumerWidget {
  const TransactionSummary({
    required this.income,
    required this.expense,
    super.key,
  });

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeHidden = ref.watch(incomeHiddenProvider);
    final colors = context.financeColors;
    final balance = income - expense;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            _SummaryCell(
              label: tr('Income'),
              amount: income,
              color: colors.income,
              hidden: incomeHidden
                  ? HiddenIncome(
                      spent: spentShare(income: income, expense: expense),
                    )
                  : null,
            ),
            _SummaryCell(
              label: tr('Expense'),
              amount: expense,
              color: colors.expense,
            ),
            // The balance of the period would give the income away.
            _SummaryCell(
              label: tr('Balance'),
              amount: balance,
              color: balance < 0 ? colors.expense : null,
              hidden: incomeHidden ? const HiddenIncome() : null,
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
    this.hidden,
  });

  final String label;
  final int amount;
  final Color? color;

  /// Shown instead of the amount while income is hidden.
  final Widget? hidden;

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
          hidden ??
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
