import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

/// The expenses of [month] that count against a category budget: the ones in
/// [categoryIds] (the category and everything inside it), newest first.
/// Balance fixes and transfers are left out, as in the budget itself.
List<TransactionItem> budgetEntries(
  Iterable<TransactionItem> items,
  Set<int> categoryIds,
) => [
  for (final item in items)
    if (item.type == TransactionType.expense &&
        !item.isAdjustment &&
        categoryIds.contains(item.categoryId))
      item,
];

/// Shows what was spent against the budget of [name] in [month].
Future<void> showBudgetEntries(
  BuildContext context, {
  required String name,
  required DateTime month,
  required Set<int> categoryIds,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      _BudgetEntriesSheet(name: name, month: month, categoryIds: categoryIds),
);

class _BudgetEntriesSheet extends ConsumerWidget {
  const _BudgetEntriesSheet({
    required this.name,
    required this.month,
    required this.categoryIds,
  });

  final String name;
  final DateTime month;
  final Set<int> categoryIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(transactionsInRangeProvider(monthRange(month)));
    final entries = budgetEntries(async.value ?? const [], categoryIds);
    final total = entries.fold<int>(0, (sum, item) => sum + item.amount);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                Text(
                  tr('{amount} spent this month', {
                    'amount': formatPoisha(total),
                  }),
                  key: const ValueKey('budget-entries-total'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.isLoading && async.value == null
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                ? Center(child: Text(tr('Nothing spent here this month.')))
                : ListView.builder(
                    controller: scroll,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return TransactionTile(
                        key: ValueKey('budget-entry-${item.id}'),
                        item: item,
                        showDate: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(AppRoutes.editTransaction(item.id));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
