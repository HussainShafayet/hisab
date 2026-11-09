import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/category_standing.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Under the category on the entry form: what the category holds this month
/// (with this entry added once an amount is typed) and what is left of the
/// budget that covers it.
class CategoryStandingNote extends StatelessWidget {
  const CategoryStandingNote({
    required this.line,
    required this.categoryName,
    required this.type,
    required this.when,
    super.key,
  });

  final StandingLine line;
  final String categoryName;
  final TransactionType type;

  /// "this month", or the name of another month.
  final String when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final params = {
      'name': categoryName,
      'when': when,
      'now': formatPoisha(line.now),
      'after': formatPoisha(line.after),
    };
    final spent = type == TransactionType.expense;
    final money = line.hasEntry
        ? (spent
              ? tr('Spent on {name} {when}: {now}, {after} after this', params)
              : tr(
                  'Received in {name} {when}: {now}, {after} after this',
                  params,
                ))
        : (spent
              ? tr('Spent on {name} {when}: {now}', params)
              : tr('Received in {name} {when}: {now}', params));

    final left = line.budgetLeft;
    final leftAfter = line.budgetLeftAfter;
    String? budget;
    var over = false;
    if (left != null && leftAfter != null) {
      final budgetParams = {
        'name': line.budgetName ?? categoryName,
        'left': formatPoisha(left),
        'after': formatPoisha(leftAfter),
        'over': formatPoisha(-(line.hasEntry ? leftAfter : left)),
      };
      if (line.hasEntry) {
        over = leftAfter < 0;
        budget = over
            ? tr('Budget for {name}: over by {over} after this', budgetParams)
            : tr(
                'Budget for {name}: {left} left, {after} after this',
                budgetParams,
              );
      } else {
        over = left < 0;
        budget = over
            ? tr('Budget for {name}: over by {over}', budgetParams)
            : tr('Budget for {name}: {left} left', budgetParams);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(money, key: const ValueKey('standing-money'), style: muted),
          if (budget != null)
            Text(
              budget,
              key: const ValueKey('standing-budget'),
              style: muted?.copyWith(
                color: over ? colors.expense : null,
                fontWeight: over ? FontWeight.w600 : null,
              ),
            ),
        ],
      ),
    );
  }
}
