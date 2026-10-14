import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_format.dart';

/// On Home: what is put into businesses and what they have made. Not shown
/// when there are no investments.
class InvestmentsHomeCard extends ConsumerWidget {
  const InvestmentsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(investmentsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final totals = investmentTotals(items);
    final color = totals.totalReturn > 0
        ? colors.income
        : totals.totalReturn < 0
        ? colors.expense
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      key: const ValueKey('investments-home-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.investments),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Investments'),
                      style: theme.textTheme.titleSmall,
                    ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Put in'), style: theme.textTheme.labelMedium),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatPoisha(totals.putIn),
                            key: const ValueKey('home-investments-put-in'),
                            style: theme.textTheme.titleLarge?.tabular.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totals.totalReturn < 0
                              ? tr('Loss so far')
                              : tr('Return so far'),
                          style: theme.textTheme.labelMedium,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            totals.roiPercent == null
                                ? formatReturn(totals.totalReturn)
                                : '${formatReturn(totals.totalReturn)}  '
                                      '${formatRoi(totals.roiPercent)}',
                            key: const ValueKey('home-investments-return'),
                            style: theme.textTheme.titleLarge?.tabular.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
