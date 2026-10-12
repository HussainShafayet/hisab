import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
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
        ],
      ),
    );
  }
}
