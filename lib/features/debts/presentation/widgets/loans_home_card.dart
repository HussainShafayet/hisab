import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/credit_card_tile.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';

/// On Home: what I will get and what I will give (loans and credit cards),
/// with a red line when something is late or a card bill is close. Not shown
/// when there is nothing to get or give.
class LoansHomeCard extends ConsumerWidget {
  const LoansHomeCard({super.key});

  /// A card bill this many days away or less is pointed out.
  static const billSoonDays = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(debtsProvider).value ?? const <DebtItem>[];
    final cards = ref.watch(creditCardsProvider);
    final today = ref.read(clockProvider)();
    final totals = debtTotals(items, today);
    final cardsOwed = totalOwed(cards);
    final toGive = totals.toPay + cardsOwed;
    if (totals.toReceive == 0 && toGive == 0) return const _EmptyLoansCard();

    final theme = Theme.of(context);
    final colors = context.financeColors;

    // The card whose bill comes first, if one is close.
    final billSoon = cards
        .where(
          (c) =>
              c.hasBill &&
              c.daysUntilDue(today) != null &&
              c.daysUntilDue(today)! <= billSoonDays,
        )
        .fold<CreditCardStatus?>(
          null,
          (best, c) =>
              best == null || c.daysUntilDue(today)! < best.daysUntilDue(today)!
              ? c
              : best,
        );

    Widget side(String key, String label, int amount, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPoisha(amount),
              key: ValueKey(key),
              style: theme.textTheme.titleLarge?.tabular.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    final warnings = [
      if (totals.overdueCount == 1)
        tr('1 loan is late')
      else if (totals.overdueCount > 1)
        tr('{count} loans are late', {'count': totals.overdueCount}),
      if (billSoon != null)
        '${billSoon.account.name}: ${cardDueText(billSoon, today)}',
    ];

    return Card(
      key: const ValueKey('loans-home-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.debts),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('Loans'), style: theme.textTheme.titleSmall),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  side(
                    'home-to-get',
                    tr("I'll get"),
                    totals.toReceive,
                    colors.income,
                  ),
                  const SizedBox(width: 16),
                  side('home-to-give', tr("I'll give"), toGive, colors.expense),
                ],
              ),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: colors.expense),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          warning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.expense,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('home-add-loan'),
                  onPressed: () => context.push(AppRoutes.newDebt),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('Add loan')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while there are no loans, so the feature can be found from Home.
class _EmptyLoansCard extends StatelessWidget {
  const _EmptyLoansCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('loans-home-empty'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.handshake_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Loans'), style: theme.textTheme.titleSmall),
                  Text(
                    tr('Lent or borrowed money? Keep track of it here.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: const ValueKey('home-add-first-loan'),
              onPressed: () => context.push(AppRoutes.newDebt),
              child: Text(tr('Add loan')),
            ),
          ],
        ),
      ),
    );
  }
}
