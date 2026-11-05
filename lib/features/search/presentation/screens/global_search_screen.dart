import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/search/domain/search_results.dart';
import 'package:hishab/features/search/presentation/providers/search_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/presentation/open_entries.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

/// One box that looks through the transactions, accounts, categories and
/// loans, and opens what is tapped.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = searchAll(
      _query,
      transactions: ref.watch(searchTransactionsProvider).value ?? const [],
      accounts: ref.watch(accountsProvider(false)).value ?? const [],
      categories: ref.watch(categoriesProvider(false)).value ?? const [],
      loans: ref.watch(debtsProvider).value ?? const [],
    );
    final byId = <int, Category>{
      for (final c in ref.watch(categoriesProvider(true)).value ?? const [])
        c.id: c,
    };

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('global-search'),
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: tr('Search everything'),
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_query.trim().length < 2)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr(
                  'Type a name, a note, a category or an amount. It looks '
                  'through your transactions, accounts, categories and '
                  'loans.',
                ),
                key: const ValueKey('search-hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr('Nothing matches "{query}".', {'query': _query.trim()}),
                key: const ValueKey('search-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          if (results.transactions.isNotEmpty) ...[
            heading(tr('Transactions')),
            for (final item in results.transactions)
              TransactionTile(
                key: ValueKey('search-tx-${item.id}'),
                item: item,
                showDate: true,
                onTap: () => context.push(AppRoutes.editTransaction(item.id)),
              ),
            if (results.moreTransactions > 0)
              ListTile(
                key: const ValueKey('search-more'),
                leading: const Icon(Icons.list_alt_outlined),
                title: Text(
                  tr('See all {n} in the list', {
                    'n': results.transactions.length + results.moreTransactions,
                  }),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openEntries(
                  context,
                  title: _query.trim(),
                  filter: TransactionFilter(query: _query),
                ),
              ),
          ],
          if (results.accounts.isNotEmpty) ...[
            heading(tr('Accounts')),
            for (final item in results.accounts)
              ListTile(
                key: ValueKey('search-account-${item.account.id}'),
                leading: Icon(
                  item.account.type.icon,
                  color: item.account.type.color,
                ),
                title: Text(item.account.name),
                subtitle: Text(formatPoisha(item.balance)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(AppRoutes.accountDetails(item.account.id)),
              ),
          ],
          if (results.categories.isNotEmpty) ...[
            heading(tr('Categories')),
            for (final category in results.categories)
              ListTile(
                key: ValueKey('search-category-${category.id}'),
                leading: CategoryAvatar(
                  icon: category.icon,
                  color: category.color,
                  radius: 16,
                ),
                title: Text(categoryPathLabel(category, byId)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openEntries(
                  context,
                  title: category.name,
                  filter: TransactionFilter(
                    categoryId: category.id,
                    categoryScope: categoryAndDescendantIds(
                      category.id,
                      byId.values,
                    ),
                  ),
                ),
              ),
          ],
          if (results.loans.isNotEmpty) ...[
            heading(tr('Loans')),
            for (final item in results.loans)
              ListTile(
                key: ValueKey('search-loan-${item.debt.id}'),
                leading: const Icon(Icons.handshake_outlined),
                title: Text(item.debt.person),
                subtitle: Text(
                  item.isSettled
                      ? tr('All paid')
                      : tr('{amount} left', {
                          'amount': formatPoisha(item.remaining),
                        }),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.debt(item.debt.id)),
              ),
          ],
        ],
      ),
    );
  }
}
