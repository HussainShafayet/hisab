import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/budget/domain/afford.dart';
import 'package:hishab/features/budget/domain/safe_to_spend.dart';

/// "Can I afford it?": type a price and see what buying it does to today's
/// share, the month's budget and the money in the accounts.
Future<void> showAffordSheet(
  BuildContext context, {
  required SafeToSpend? safe,
  required int totalBalance,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AffordSheet(safe: safe, totalBalance: totalBalance),
);

class _AffordSheet extends StatefulWidget {
  const _AffordSheet({required this.safe, required this.totalBalance});

  final SafeToSpend? safe;
  final int totalBalance;

  @override
  State<_AffordSheet> createState() => _AffordSheetState();
}

class _AffordSheetState extends State<_AffordSheet> {
  final _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  String _words(AffordCheck check) {
    final amount = formatPoisha(check.amount);
    return switch (check.verdict) {
      AffordVerdict.fitsToday => tr(
        'Yes, go ahead. You will still have {amount} to spend today.',
        {'amount': amount},
      ),
      AffordVerdict.fitsBalance => tr(
        'Your accounts can pay for it. {amount} would be left.',
        {'amount': amount},
      ),
      AffordVerdict.eatsDays => tr(
        'You can, but it uses up {days} of your daily share. After it, about '
        '{amount} a day.',
        {'days': plural(check.days, '1 day', '{n} days'), 'amount': amount},
      ),
      AffordVerdict.overBudget => tr(
        'It goes over this month\'s budget by {amount}. Sleep on it?',
        {'amount': amount},
      ),
      AffordVerdict.overBalance => tr(
        'That is {amount} more than the money in your accounts.',
        {'amount': amount},
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final price = parseTakaToPoisha(_price.text);
    final check = price == null || price <= 0
        ? null
        : affordCheck(
            price: price,
            safe: widget.safe,
            totalBalance: widget.totalBalance,
          );
    final good =
        check?.verdict == AffordVerdict.fitsToday ||
        check?.verdict == AffordVerdict.fitsBalance;
    final warn = check?.verdict == AffordVerdict.eatsDays;
    final color = good
        ? colors.income
        : warn
        ? theme.colorScheme.tertiary
        : colors.expense;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Can I afford it?'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            MoneyFormField(
              key: const ValueKey('afford-price'),
              controller: _price,
              label: tr('Price'),
              autofocus: true,
              isRequired: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (check != null)
              Card(
                key: const ValueKey('afford-result'),
                color: color.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        good
                            ? Icons.check_circle_outline
                            : warn
                            ? Icons.hourglass_bottom
                            : Icons.warning_amber_rounded,
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _words(check),
                          key: const ValueKey('afford-text'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                tr('Type the price to see what buying it does.'),
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
