import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';
import 'package:hishab/features/accounts/presentation/widgets/adjust_balance_dialog.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(
              _showArchived ? Icons.visibility : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newAccount),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: accounts.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(accountsProvider(_showArchived)),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add your cash, mobile banking and bank accounts.',
                action: FilledButton(
                  onPressed: () => context.push(AppRoutes.newAccount),
                  child: const Text('Add account'),
                ),
              )
            : _AccountsList(accounts: list),
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.accounts});

  final List<AccountWithBalance> accounts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _TotalCard(accounts: accounts),
        for (final item in accounts) _AccountTile(item: item),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.accounts});

  final List<AccountWithBalance> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = calculateTotalBalance(accounts);
    final counted = accounts
        .where((a) => a.account.includeInTotal && !a.account.isArchived)
        .length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total balance', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              formatPoisha(total),
              style: theme.textTheme.headlineMedium?.tabular.copyWith(
                fontWeight: FontWeight.w600,
                color: total < 0 ? context.financeColors.expense : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              counted == 1
                  ? '1 account included'
                  : '$counted accounts included',
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

enum _AccountAction { edit, adjust, archive, restore }

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.item});

  final AccountWithBalance item;

  Account get _account => item.account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = _account.isArchived;
    final notes = [
      _account.type.label,
      if (!_account.includeInTotal) 'Not in total',
      if (_account.isArchived) 'Archived',
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Icon(_account.type.icon),
      ),
      title: Text(
        _account.name,
        style: muted
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(notes.join(' · ')),
      onTap: () => context.push(AppRoutes.editAccount(_account.id)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPoisha(item.balance),
            style: theme.textTheme.titleMedium?.tabular.copyWith(
              color: item.balance < 0
                  ? context.financeColors.expense
                  : muted
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          PopupMenuButton<_AccountAction>(
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _AccountAction.edit,
                child: Text('Edit'),
              ),
              const PopupMenuItem(
                value: _AccountAction.adjust,
                child: Text('Adjust balance'),
              ),
              if (_account.isArchived)
                const PopupMenuItem(
                  value: _AccountAction.restore,
                  child: Text('Restore'),
                )
              else
                const PopupMenuItem(
                  value: _AccountAction.archive,
                  child: Text('Archive'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.edit:
        await context.push(AppRoutes.editAccount(_account.id));
      case _AccountAction.adjust:
        await _adjust(context);
      case _AccountAction.archive:
        await _archive(context, ref);
      case _AccountAction.restore:
        await _restore(context, ref);
    }
  }

  Future<void> _adjust(BuildContext context) async {
    final adjustment = await showDialog<BalanceAdjustment>(
      context: context,
      builder: (context) => AdjustBalanceDialog(item: item),
    );
    if (adjustment == null || !context.mounted) return;
    final kind = adjustment.type == TransactionType.income
        ? 'income'
        : 'expense';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recorded ${formatPoisha(adjustment.amount)} $kind '
          'on ${_account.name}',
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive "${_account.name}"?'),
        content: const Text(
          'It will be hidden from lists and left out of the total balance. '
          'Its transactions are kept, and you can restore it any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repository = ref.read(accountsRepositoryProvider);
    await repository.archiveAccount(_account.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_account.name} archived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.restoreAccount(_account.id),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(accountsRepositoryProvider).restoreAccount(_account.id);
    } on ValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
