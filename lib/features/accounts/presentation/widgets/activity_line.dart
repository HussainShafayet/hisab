import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account_activity.dart';

/// "This month: in ৳50,000 · out ৳12,300 · 14 entries", under an account card.
class ActivityLine extends StatelessWidget {
  const ActivityLine({required this.activity, this.hidden = false, super.key});

  final AccountActivity? activity;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final data = activity;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (data == null || data.count == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Text(tr('Nothing this month'), style: style),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Wrap(
        spacing: 12,
        children: [
          Text(
            hidden
                ? tr('In {amount}', {'amount': hiddenAmountText})
                : tr('In {amount}', {'amount': formatPoisha(data.inflow)}),
            style: style?.copyWith(color: colors.income),
          ),
          Text(
            hidden
                ? tr('Out {amount}', {'amount': hiddenAmountText})
                : tr('Out {amount}', {'amount': formatPoisha(data.outflow)}),
            style: style?.copyWith(color: colors.expense),
          ),
          Text(
            plural(data.count, '1 entry this month', '{n} entries this month'),
            style: style,
          ),
        ],
      ),
    );
  }
}
