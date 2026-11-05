import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/debts/domain/loan_insights.dart';
import 'package:intl/intl.dart';

/// "Pay it off in 6 months": what to pay each month to finish, for a loan that
/// is not paid yet. For money lent it is the same sum to ask for each month.
class PayoffCard extends StatefulWidget {
  const PayoffCard({
    required this.remaining,
    required this.lent,
    required this.today,
    super.key,
  });

  final int remaining;
  final bool lent;
  final DateTime today;

  @override
  State<PayoffCard> createState() => _PayoffCardState();
}

class _PayoffCardState extends State<PayoffCard> {
  static const _choices = [3, 6, 12];
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = payoffPlan(widget.remaining, _months);
    if (plan == null) return const SizedBox.shrink();
    final end = payoffEnd(plan, widget.today);
    final monthly = formatPoisha(plan.monthly);
    final line = plan.months == 1
        ? tr('One payment of {amount}.', {'amount': formatPoisha(plan.last)})
        : plan.last == plan.monthly
        ? tr('{amount} a month for {n} months.', {
            'amount': monthly,
            'n': plan.months,
          })
        : tr('{amount} a month for {n} months, the last one {last}.', {
            'amount': monthly,
            'n': plan.months,
            'last': formatPoisha(plan.last),
          });
    return Card(
      key: const ValueKey('payoff-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lent
                  ? tr('Get it back in parts')
                  : tr('Pay it off in parts'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final months in _choices)
                  ChoiceChip(
                    key: ValueKey('payoff-$months'),
                    showCheckmark: false,
                    label: Text(plural(months, '1 month', '{n} months')),
                    selected: _months == months,
                    onSelected: (_) => setState(() => _months = months),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              line,
              key: const ValueKey('payoff-line'),
              style: theme.textTheme.titleMedium?.tabular,
            ),
            const SizedBox(height: 2),
            Text(
              tr('Done by {month}.', {
                'month': localizeDigits(DateFormat('MMMM yyyy').format(end)),
              }),
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
