import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/fun/presentation/widgets/takka_card.dart';
import 'package:hishab/features/fun/domain/quips.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/domain/overdrawn.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/presentation/widgets/overdrawn_card.dart';
import 'package:hishab/features/budget/domain/safe_to_spend.dart';
import 'package:hishab/features/dashboard/domain/dashboard_data.dart';
import 'package:hishab/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:hishab/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:hishab/features/dashboard/presentation/widgets/safe_to_spend_card.dart';
import 'package:hishab/features/dashboard/presentation/widgets/home_shortcuts.dart';
import 'package:hishab/features/fun/presentation/widgets/regret_meter_card.dart';
import 'package:hishab/features/fun/presentation/widgets/streak_card.dart';
import 'package:hishab/features/fun/presentation/widgets/wrapped_home_card.dart';
import 'package:hishab/features/goals/presentation/widgets/festival_home_card.dart';
import 'package:hishab/features/debts/presentation/widgets/loans_home_card.dart';
import 'package:hishab/features/insights/presentation/widgets/insights_card.dart';
import 'package:hishab/features/investments/presentation/widgets/investments_home_card.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/recurring/presentation/widgets/due_recurring_card.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/help/presentation/widgets/welcome_card.dart';

/// The Home tab: where the money stands this month at a glance.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Home')),
        actions: const [HelpButton('home')],
      ),
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
    final budget = data.overallBudget;
    final safeToSpend = safeToSpendOf(
      budget: budget?.limit,
      spentThisMonth: budget?.spent ?? 0,
      spentToday: data.todayExpense,
      rules: ref.watch(recurringRulesProvider).value ?? const [],
      today: now,
    );

    final accounts =
        ref.watch(accountsProvider(false)).value ??
        const <AccountWithBalance>[];
    final quipInputs = QuipInputs(
      now: now,
      overdrawnCount: overdrawnAccounts(accounts).length,
      budgetPercent: budget?.progress.percent,
      spentToday: data.todayExpense,
    );

    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: _arriving([
        const WelcomeCard(),
        TakkaCard(inputs: quipInputs),
        const WrappedHomeCard(),
        const StreakCard(),
        const DueRecurringCard(),
        TotalBalanceCard(balance: data.totalBalance),
        const OverdrawnCard(),
        const WalletStrip(),
        const HomeShortcuts(),
        SafeToSpendCard(figures: safeToSpend, totalBalance: data.totalBalance),
        const LoansHomeCard(),
        const InvestmentsHomeCard(),
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
        const RegretMeterCard(),
        const FestivalHomeCard(),
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
      ]),
    );
  }
}

/// The first cards of Home arrive one after another. The ones further down
/// are plain, so scrolling back up never replays an animation.
List<Widget> _arriving(List<Widget> cards) => [
  for (final (index, card) in cards.indexed)
    if (index < 7) FadeSlideIn(index: index, child: card) else card,
];
