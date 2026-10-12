import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/debt_tile.dart';

/// Money lent to and borrowed from people: what is still to get back and
/// what is still to pay back.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final today = ref.read(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(tr('Loans'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newDebt),
        icon: const Icon(Icons.add),
        label: Text(tr('Add loan')),
      ),
      body: debts.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(debtsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.handshake_outlined,
              title: tr('No loans yet'),
              message: tr(
                'Note down money you lent or borrowed, and tick it off as it '
                'is paid back.',
              ),
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.newDebt),
                child: Text(tr('Add loan')),
              ),
            );
          }
          final totals = debtTotals(items, today);
          final shown = sortDebts(
            items.where((i) => _showSettled || !i.isSettled),
            today,
          );
          final hasSettled = items.any((i) => i.isSettled);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _Summary(totals: totals),
              if (hasSettled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      key: const ValueKey('show-settled'),
                      avatar: const Icon(Icons.done_all, size: 18),
                      label: Text(tr('Show settled')),
                      selected: _showSettled,
                      onSelected: (value) =>
                          setState(() => _showSettled = value),
                    ),
                  ),
                ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(tr('Everything is settled.'))),
                ),
              for (final item in shown)
                DebtTile(
                  key: ValueKey('debt-${item.debt.id}'),
                  item: item,
                  today: today,
                  onTap: () => context.push(AppRoutes.debt(item.debt.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.totals});

  final DebtTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;

    Widget side(String key, String label, int amount, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPoisha(amount),
              key: ValueKey(key),
              style: theme.textTheme.headlineSmall?.tabular.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                side(
                  'to-get-back',
                  tr('To get back'),
                  totals.toReceive,
                  colors.income,
                ),
                const SizedBox(width: 16),
                side(
                  'to-pay-back',
                  tr('To pay back'),
                  totals.toPay,
                  colors.expense,
                ),
              ],
            ),
            if (totals.overdueCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: colors.expense),
                  const SizedBox(width: 6),
                  Text(
                    totals.overdueCount == 1
                        ? tr('1 loan is overdue')
                        : tr('{count} loans are overdue', {
                            'count': totals.overdueCount,
                          }),
                    key: const ValueKey('overdue-count'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
