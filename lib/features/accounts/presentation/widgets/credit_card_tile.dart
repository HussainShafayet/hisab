import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/card_charge_sheet.dart';
import 'package:intl/intl.dart';

/// "Bill due 15 Oct", "Bill due today" or "Bill due tomorrow", or null when
/// the card has no bill day.
String? cardDueText(CreditCardStatus card, DateTime today) {
  final days = card.daysUntilDue(today);
  if (days == null) return null;
  if (days == 0) return tr('Bill due today');
  if (days == 1) return tr('Bill due tomorrow');
  return tr('Bill due {date}', {
    'date': DateFormat('d MMM').format(card.nextDue(today)!),
  });
}

/// A credit card as a wallet card with what is owed and what is left to
/// spend, the day the bill is due, and a "Pay bill" button.
class CreditCardTile extends StatelessWidget {
  const CreditCardTile({
    required this.card,
    required this.today,
    required this.onTap,
    required this.onPay,
    super.key,
  });

  final CreditCardStatus card;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          AccountCard(
            account: card.account,
            balance: card.balance,
            onTap: onTap,
          ),
          CreditCardDetails(card: card, today: today, onPay: onPay),
        ],
      ),
    );
  }
}

/// What goes under a credit card's wallet card: the day the bill is due, the
/// "Pay bill" and "Add a charge" buttons, what to do when the limit is passed,
/// and, for a card with dollars, the dollars spent, what is still due in
/// dollars and what is left to spend.
class CreditCardDetails extends ConsumerWidget {
  const CreditCardDetails({
    required this.card,
    required this.today,
    required this.onPay,
    super.key,
  });

  final CreditCardStatus card;
  final DateTime today;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final due = cardDueText(card, today);
    final days = card.daysUntilDue(today);
    final soon = card.hasBill && days != null && days <= 3;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  card.hasBill
                      ? (due ?? tr('Set a bill day to get reminders'))
                      : tr('Nothing owed'),
                  key: ValueKey('card-due-${card.account.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: soon
                        ? colors.expense
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: soon ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (card.hasBill)
                FilledButton.tonalIcon(
                  key: ValueKey('pay-bill-${card.account.id}'),
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(tr('Pay bill')),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-charge-${card.account.id}'),
            onPressed: () =>
                addCardCharge(context, ref, cardId: card.account.id),
            icon: const Icon(Icons.add_card_outlined, size: 18),
            label: Text(tr('Add a late fee or charge')),
          ),
        ),
        if (card.isOverLimit) _OverLimit(card: card),
        if (card.showsDollars) _DollarLines(card: card),
      ],
    );
  }
}

/// What to do when the limit is passed: the bank may allow it and charge a
/// fee, so there are three ways on: pay the extra, ask the bank for a higher
/// limit and write it here, or write the fee. Nothing is blocked.
class _OverLimit extends StatelessWidget {
  const _OverLimit({required this.card});

  final CreditCardStatus card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final id = card.account.id;
    final left = card.takaLeft;
    final extra = left != null && left < 0 ? -left : 0;
    return Container(
      key: ValueKey('card-over-limit-$id'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: colors.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            extra > 0
                ? tr('{amount} is over the limit of this card.', {
                    'amount': formatPoisha(extra),
                  })
                : tr('The dollar limit of this card is passed.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.expense,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              'Spending is never blocked. Pay the extra, ask the bank for a '
              'higher limit, or write down the fee it charged.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              if (extra > 0)
                TextButton(
                  key: ValueKey('pay-extra-$id'),
                  onPressed: () =>
                      context.push(AppRoutes.payCardBill(id, extra)),
                  child: Text(tr('Pay the extra')),
                ),
              TextButton(
                key: ValueKey('raise-limit-$id'),
                onPressed: () => context.push(AppRoutes.editAccount(id)),
                child: Text(tr('Change the limit')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dollar side of a card: spent this month, still due, and what is left
/// to spend in taka and in dollars.
class _DollarLines extends StatelessWidget {
  const _DollarLines({required this.card});

  final CreditCardStatus card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = card.account.id;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final usdLeft = card.usdLeft;
    final takaLeft = card.takaLeft;
    final totalLeft = card.totalLeft;

    Widget line(String key, String text, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        key: ValueKey('$key-$id'),
        style: strong
            ? style?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              )
            : style,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(
              'card-usd-spent',
              tr('Spent in dollars this month: {amount}', {
                'amount': formatUsd(card.dollars.spentThisMonth),
              }),
            ),
            line(
              'card-usd-due',
              tr('Dollars still due: {amount}', {
                'amount': formatUsd(card.dollars.due),
              }),
              strong: card.dollars.due > 0,
            ),
            if (usdLeft != null)
              line(
                'card-usd-left',
                takaLeft == null
                    ? tr('Left in dollars: {usd}', {'usd': formatUsd(usdLeft)})
                    : tr('Left: {taka} in taka and {usd} in dollars', {
                        'taka': formatPoisha(takaLeft),
                        'usd': formatUsd(usdLeft),
                      }),
              ),
            if (totalLeft != null)
              line(
                'card-usd-total',
                tr('About {amount} left in all', {
                  'amount': formatPoisha(totalLeft),
                }),
              ),
          ],
        ),
      ),
    );
  }
}
