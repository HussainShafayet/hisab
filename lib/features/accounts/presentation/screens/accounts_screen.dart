import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/show_archived_chip.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';
import 'package:hishab/features/accounts/presentation/widgets/adjust_balance_dialog.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Every wallet as a card, with the total on top.
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
      appBar: AppBar(title: const Text('Accounts')),
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
        data: (list) => ListView(
          // Room below the last card so the add button never covers it.
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (list.isNotEmpty) _TotalCard(accounts: list),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ShowArchivedChip(
                value: _showArchived,
                onChanged: (value) => setState(() => _showArchived = value),
              ),
            ),
            if (list.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add your cash, mobile banking and bank accounts.',
                action: FilledButton(
                  onPressed: () => context.push(AppRoutes.newAccount),
                  child: const Text('Add account'),
                ),
              )
            else
              for (final item in list)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _AccountCardTile(item: item),
                ),
          ],
        ),
      ),
    );
  }
}

/// The total balance, big, with how much of it is in each kind of account.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.accounts});

  final List<AccountWithBalance> accounts;

  static const _white = Colors.white;
  static const _whiteSoft = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = calculateTotalBalance(accounts);
    final byType = totalByAccountType(accounts);
    final counted = accounts
        .where((a) => a.account.includeInTotal && !a.account.isArchived)
        .length;
    final primary = theme.colorScheme.primary;

    return Container(
      key: const ValueKey('total-card'),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, 0.45)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total balance',
            style: theme.textTheme.labelLarge?.copyWith(color: _whiteSoft),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPoisha(total),
              key: const ValueKey('total-balance'),
              style: theme.textTheme.displaySmall?.tabular.copyWith(
                fontWeight: FontWeight.w700,
                color: total < 0 ? const Color(0xFFFFE082) : _white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            counted == 1 ? '1 account included' : '$counted accounts included',
            style: theme.textTheme.bodySmall?.copyWith(color: _whiteSoft),
          ),
          if (byType.length > 1) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0x44FFFFFF)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                for (final entry in byType.entries)
                  _TypeStat(
                    key: ValueKey('type-total-${entry.key.name}'),
                    icon: entry.key.icon,
                    label: entry.key.label,
                    amount: entry.value,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeStat extends StatelessWidget {
  const _TypeStat({
    required this.icon,
    required this.label,
    required this.amount,
    super.key,
  });

  final IconData icon;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xCCFFFFFF)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xCCFFFFFF),
              ),
            ),
            Text(
              formatPoisha(amount),
              style: theme.textTheme.titleSmall?.tabular.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _AccountAction { edit, adjust, archive, restore }

/// One wallet card, with its menu: edit, adjust the balance, archive.
class _AccountCardTile extends ConsumerWidget {
  const _AccountCardTile({required this.item});

  final AccountWithBalance item;

  Account get _account => item.account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountCard(
      key: ValueKey('account-card-${_account.id}'),
      account: _account,
      balance: item.balance,
      onTap: () => context.push(AppRoutes.editAccount(_account.id)),
      trailing: PopupMenuButton<_AccountAction>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (context) => [
          const PopupMenuItem(value: _AccountAction.edit, child: Text('Edit')),
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
