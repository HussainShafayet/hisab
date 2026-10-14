import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_format.dart';

/// One investment in the list: what was put in, what it has made so far.
class InvestmentTile extends StatelessWidget {
  const InvestmentTile({required this.item, required this.onTap, super.key});

  final InvestmentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final investment = item.investment;
    final color = switch (item.standing) {
      InvestmentStanding.gain => colors.income,
      InvestmentStanding.loss => colors.expense,
      InvestmentStanding.even => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      investment.isClosed
                          ? tr('Closed · put in {amount}', {
                              'amount': formatPoisha(item.putIn),
                            })
                          : tr('Put in {amount}', {
                              'amount': formatPoisha(item.putIn),
                            }),
                      key: ValueKey('investment-put-in-${investment.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatReturn(item.totalReturn),
                        key: ValueKey('investment-return-${investment.id}'),
                        style: theme.textTheme.titleSmall?.tabular.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.roiPercent != null)
                      Text(
                        formatRoi(item.roiPercent),
                        key: ValueKey('investment-roi-${investment.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
