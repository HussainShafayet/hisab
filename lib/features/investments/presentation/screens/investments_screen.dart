import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_summary.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_tile.dart';

/// The money put into businesses and other ventures, and what each has made.
class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Investments'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newInvestment),
        icon: const Icon(Icons.add),
        label: Text(tr('New investment')),
      ),
      body: investments.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              title: tr('No investments yet'),
              message: tr(
                'Put money into a shop, a farm or a partnership, and see '
                'what it earns. Add each taka you put in and each profit you '
                'get.',
              ),
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.newInvestment),
                child: Text(tr('New investment')),
              ),
            );
          }
          final totals = investmentTotals(list);
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              InvestmentSummary(
                keyPrefix: 'investments',
                totalReturn: totals.totalReturn,
                roiPercent: totals.roiPercent,
                stats: [
                  InvestmentStat(
                    label: tr('Put in'),
                    amount: totals.putIn,
                    key: 'investments-put-in',
                  ),
                  InvestmentStat(
                    label: tr('Profit received'),
                    amount: totals.profit,
                    key: 'investments-profit',
                  ),
                  InvestmentStat(
                    label: tr('Worth now'),
                    amount: totals.value,
                    key: 'investments-value',
                  ),
                ],
              ),
              for (final item in list)
                InvestmentTile(
                  key: ValueKey('investment-${item.investment.id}'),
                  item: item,
                  onTap: () =>
                      context.push(AppRoutes.investment(item.investment.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}
