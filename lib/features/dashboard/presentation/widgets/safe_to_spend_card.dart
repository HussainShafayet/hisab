import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/budget/domain/safe_to_spend.dart';
import 'package:hishab/features/dashboard/presentation/widgets/afford_sheet.dart';

/// "You can spend today": the daily share of what is left of the month's
/// budget, after the bills still to come. Without a budget it invites to set
/// one.
class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({
    required this.figures,
    this.totalBalance = 0,
    super.key,
  });

  /// Null when the month has no overall budget.
  final SafeToSpend? figures;

  /// The money in the accounts that count, for "Can I afford it?".
  final int totalBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final safe = figures;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            safe == null
                ? Column(
                    key: const ValueKey('safe-no-budget'),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(
                                'Set a monthly budget and Hishab tells you how '
                                'much you can spend each day.',
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      // Under the text, so a long button label has room.
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go(AppRoutes.budget),
                          child: Text(tr('Set budget')),
                        ),
                      ),
                    ],
                  )
                : _Figures(safe: safe, expense: colors.expense),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('afford-button'),
                onPressed: () => showAffordSheet(
                  context,
                  safe: safe,
                  totalBalance: totalBalance,
                ),
                icon: const Icon(Icons.help_outline, size: 18),
                label: Text(tr('Can I afford it?')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.safe, required this.expense});

  final SafeToSpend safe;
  final Color expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bad = safe.isUsedUp || safe.isOverToday;

    final String headline;
    final String label;
    if (safe.isUsedUp) {
      headline = formatPoisha(-safe.remaining);
      label = tr('Over the budget, counting the bills to come');
    } else if (safe.isOverToday) {
      headline = formatPoisha(-safe.leftToday);
      label = tr('Over today\'s share');
    } else {
      headline = formatPoisha(safe.leftToday);
      label = tr('You can spend today');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              bad ? Icons.warning_amber_rounded : Icons.payments_outlined,
              size: 20,
              color: bad ? expense : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                key: const ValueKey('safe-label'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          headline,
          key: const ValueKey('safe-amount'),
          style: theme.textTheme.headlineSmall?.tabular.copyWith(
            fontWeight: FontWeight.w700,
            color: bad ? expense : null,
          ),
        ),
        if (!safe.isUsedUp) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: safe.usedToday,
              minHeight: 6,
              color: safe.isOverToday ? expense : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('{share} a day · {spent} spent today', {
              'share': formatPoisha(safe.perDay),
              'spent': formatPoisha(safe.spentToday),
            }),
            key: const ValueKey('safe-detail'),
            style: muted,
          ),
        ],
        const SizedBox(height: 2),
        Text(
          safe.upcomingBills > 0
              ? tr(
                  '{left} of the budget is left for {days} days, after '
                  '{bills} of bills still to come.',
                  {
                    'left': formatPoisha(safe.budget - safe.spentBeforeToday),
                    'days': safe.daysLeft,
                    'bills': formatPoisha(safe.upcomingBills),
                  },
                )
              : tr('{left} of the budget is left for {days} days.', {
                  'left': formatPoisha(safe.budget - safe.spentBeforeToday),
                  'days': safe.daysLeft,
                }),
          key: const ValueKey('safe-note'),
          style: muted,
        ),
      ],
    );
  }
}
