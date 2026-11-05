import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/month_switcher.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account_activity.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/adjust_balance_dialog.dart';
import 'package:hishab/features/accounts/presentation/widgets/credit_card_tile.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/domain/day_groups.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

/// One account's page: its card, quick ways to add to it, and a month of what
/// came in and went out with every entry that touched it.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final month = _month ?? monthStart(now);
    final accounts = ref.watch(accountsProvider(true));
    final item = accounts.value
        ?.where((a) => a.account.id == widget.accountId)
        .firstOrNull;

    if (accounts.isLoading && item == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: tr('Account not found'),
          message: tr('It may have been removed.'),
        ),
      );
    }

    final account = item.account;
    final hidden = ref.watch(preferencesProvider.select((p) => p.hideBalances));
    final card = account.isCreditCard
        ? ref
              .watch(creditCardsProvider)
              .where((c) => c.account.id == account.id)
              .firstOrNull
        : null;
    final entries = ref.watch(transactionsInRangeProvider(monthRange(month)));
    final mine = touching(entries.value ?? const [], account.id);
    final activity = activityByAccount(mine)[account.id];
    final theme = Theme.of(context);
    final colors = context.financeColors;

    Widget stat(String label, int amount, Color? color) => Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hidden ? hiddenAmountText : formatPoisha(amount),
              style: theme.textTheme.titleMedium?.tabular.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            key: const ValueKey('detail-edit'),
            tooltip: tr('Edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.editAccount(account.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountCard(
                  key: const ValueKey('detail-card'),
                  account: account,
                  balance: item.balance,
                  hideBalance: hidden,
                ),
                if (card != null)
                  CreditCardDetails(
                    card: card,
                    today: now,
                    onPay: () => context.push(
                      AppRoutes.payCardBill(
                        account.id,
                        card.owed,
                        usd: card.dollars.due,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!account.isArchived) ...[
                  FilledButton.tonalIcon(
                    key: const ValueKey('detail-expense'),
                    onPressed: () => context.push(
                      AppRoutes.addOnAccount(
                        account.id,
                        type: TransactionType.expense.name,
                      ),
                    ),
                    icon: const Icon(Icons.remove),
                    label: Text(tr('Expense')),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('detail-income'),
                    onPressed: () => context.push(
                      AppRoutes.addOnAccount(
                        account.id,
                        type: TransactionType.income.name,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(tr('Income')),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('detail-transfer'),
                    onPressed: () => context.push(
                      AppRoutes.addOnAccount(
                        account.id,
                        type: TransactionType.transfer.name,
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(tr('Transfer')),
                  ),
                ],
                OutlinedButton.icon(
                  key: const ValueKey('detail-adjust'),
                  onPressed: () => showDialog<BalanceAdjustment>(
                    context: context,
                    builder: (context) => AdjustBalanceDialog(item: item),
                  ),
                  icon: const Icon(Icons.tune),
                  label: Text(tr('Adjust balance')),
                ),
              ],
            ),
          ),
          MonthSwitcher(
            month: month,
            canGoNext: month.isBefore(monthStart(now)),
            onPrevious: () => setState(() => _month = addMonths(month, -1)),
            onNext: () => setState(() => _month = addMonths(month, 1)),
          ),
          Card(
            key: const ValueKey('detail-summary'),
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  stat(tr('In'), activity?.inflow ?? 0, colors.income),
                  stat(tr('Out'), activity?.outflow ?? 0, colors.expense),
                  stat(
                    tr('Net'),
                    activity?.net ?? 0,
                    (activity?.net ?? 0) < 0 ? colors.expense : null,
                  ),
                ],
              ),
            ),
          ),
          if (entries.isLoading && entries.value == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  tr('Nothing on this account in {month}', {
                    'month': monthLabel(month),
                  }),
                  key: const ValueKey('detail-empty'),
                ),
              ),
            )
          else
            for (final group in groupByDay(mine)) ...[
              DayHeader(group: group, label: dayLabel(group.day, now)),
              for (final entry in group.items)
                TransactionTile(
                  key: ValueKey('detail-entry-${entry.id}'),
                  item: entry,
                  onTap: () =>
                      context.push(AppRoutes.editTransaction(entry.id)),
                ),
            ],
        ],
      ),
    );
  }
}
