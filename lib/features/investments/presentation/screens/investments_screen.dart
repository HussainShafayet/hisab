import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/domain/investment_facts.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_summary.dart';
import 'package:hishab/features/investments/presentation/widgets/investment_tile.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// The money put into businesses and other ventures, and what each has made.
class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  InvestmentFilter _filter = InvestmentFilter.all;
  InvestmentSort _sort = InvestmentSort.newest;

  @override
  Widget build(BuildContext context) {
    final investments = ref.watch(investmentsProvider);
    final today = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Investments')),
        actions: [
          const HelpButton('investments'),
          PopupMenuButton<InvestmentSort>(
            key: const ValueKey('investment-sort'),
            tooltip: tr('Sort'),
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: InvestmentSort.newest,
                child: Text(tr('Newest first')),
              ),
              PopupMenuItem(
                value: InvestmentSort.bestReturn,
                child: Text(tr('Best return first')),
              ),
              PopupMenuItem(
                value: InvestmentSort.mostPutIn,
                child: Text(tr('Most put in first')),
              ),
            ],
          ),
        ],
      ),
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
              _FilterChips(
                filter: _filter,
                all: list.length,
                open: list.where((i) => !i.investment.isClosed).length,
                closed: list.where((i) => i.investment.isClosed).length,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              if (_bestOf(list) case final best?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    tr('Best so far: {name}, {percent}%', {
                      'name': best.investment.name,
                      'percent': best.roiPercent!,
                    }),
                    key: const ValueKey('investment-best'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              for (final item in arrangeInvestments(
                list,
                filter: _filter,
                sort: _sort,
              ))
                InvestmentTile(
                  key: ValueKey('investment-${item.investment.id}'),
                  item: item,
                  heldDays: factsOf(item, today: today).heldDays,
                  onTap: () =>
                      context.push(AppRoutes.investment(item.investment.id)),
                ),
              if (arrangeInvestments(
                list,
                filter: _filter,
                sort: _sort,
              ).isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      tr('None here.'),
                      key: const ValueKey('investments-none'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The investment with the best return so far, when two or more have a percent
/// and the best one is a gain.
InvestmentItem? _bestOf(List<InvestmentItem> list) {
  final withPercent = list.where((i) => i.roiPercent != null).toList();
  if (withPercent.length < 2) return null;
  withPercent.sort((a, b) => b.roiPercent!.compareTo(a.roiPercent!));
  return withPercent.first.roiPercent! > 0 ? withPercent.first : null;
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.all,
    required this.open,
    required this.closed,
    required this.onSelected,
  });

  final InvestmentFilter filter;
  final int all;
  final int open;
  final int closed;
  final ValueChanged<InvestmentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(Key key, String label, int count, InvestmentFilter value) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: key,
            showCheckmark: false,
            label: Text(localizeDigits('$label · $count')),
            selected: filter == value,
            onSelected: (_) => onSelected(value),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(
              const ValueKey('inv-all'),
              tr('All'),
              all,
              InvestmentFilter.all,
            ),
            chip(
              const ValueKey('inv-open'),
              tr('Open'),
              open,
              InvestmentFilter.open,
            ),
            chip(
              const ValueKey('inv-closed'),
              tr('Closed'),
              closed,
              InvestmentFilter.closed,
            ),
          ],
        ),
      ),
    );
  }
}
