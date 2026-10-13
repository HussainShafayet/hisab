import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
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
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final due = cardDueText(card, today);
    final days = card.daysUntilDue(today);
    final soon = card.hasBill && days != null && days <= 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          AccountCard(
            account: card.account,
            balance: card.balance,
            onTap: onTap,
          ),
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
          if (card.showsDollars) _DollarLines(card: card),
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
          ],
        ),
      ),
    );
  }
}
