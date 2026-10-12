import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/dashboard/domain/dashboard_data.dart';
import 'package:hishab/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:hishab/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:hishab/features/insights/presentation/widgets/insights_card.dart';
import 'package:hishab/features/recurring/presentation/widgets/due_recurring_card.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

/// The Home tab: where the money stands this month at a glance.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Home'))),
      body: dashboard.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: describeError(error),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => _DashboardContent(data: data),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final totals = data.monthTotals;

    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const DueRecurringCard(),
        TotalBalanceCard(balance: data.totalBalance),
        const WalletStrip(),
        DashboardHeading(
          tr('This month · {month}', {'month': monthLabel(data.month)}),
        ),
        TransactionSummary(income: totals.income, expense: totals.expense),
        BudgetRingCard(
          budget: data.overallBudget,
          month: data.month,
          today: now,
        ),
        SpendingTiles(today: data.todayExpense, week: data.weekExpense),
        const InsightsCard(),
        DashboardHeading(tr('Top spending')),
        TopCategoriesCard(
          categories: data.topCategories,
          monthExpense: totals.expense,
        ),
        DashboardHeading(
          tr('Recent'),
          trailing: TextButton(
            onPressed: () => context.go(AppRoutes.transactions),
            child: Text(tr('See all')),
          ),
        ),
        RecentTransactionsCard(items: data.recent),
      ],
    );
  }
}
