import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A chip for each option of the filter that is set, under the app bar, each
/// with a cross that takes just that one off. Nothing when none is set.
class FilterChips extends ConsumerWidget {
  const FilterChips({required this.filter, required this.onRemove, super.key});

  final TransactionFilter filter;
  final ValueChanged<FilterOption> onRemove;

  /// What the chip of [option] says.
  String _label(
    FilterOption option, {
    required String? category,
    required String? account,
    required String? tag,
  }) => switch (option) {
    FilterOption.type => switch (filter.type!) {
      TransactionType.expense => tr('Expense'),
      TransactionType.income => tr('Income'),
      TransactionType.transfer => tr('Transfer'),
    },
    FilterOption.category => category ?? tr('Category'),
    FilterOption.account => account ?? tr('Account'),
    FilterOption.amount => switch ((filter.minAmount, filter.maxAmount)) {
      (final int min, final int max) =>
        '${formatPoisha(min)} – ${formatPoisha(max)}',
      (final int min, null) => tr('From {amount}', {
        'amount': formatPoisha(min),
      }),
      (null, final int max) => tr('Up to {amount}', {
        'amount': formatPoisha(max),
      }),
      _ => tr('Amount'),
    },
    FilterOption.tag => tag ?? tr('Trip or event'),
    FilterOption.feeling => switch (filter.feeling!) {
      Feeling.need => tr('Needed'),
      Feeling.want => tr('Wanted'),
      Feeling.regret => tr('Regret'),
    },
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = filter.activeOptions;
    if (options.isEmpty) return const SizedBox.shrink();

    final categories = ref.watch(categoriesProvider(true)).value ?? const [];
    final accounts = ref.watch(accountsProvider(true)).value ?? const [];
    final tags = ref.watch(tagsProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == filter.categoryId)
        .firstOrNull
        ?.name;
    final account = accounts
        .where((a) => a.account.id == filter.accountId)
        .firstOrNull
        ?.account
        .name;
    final tag = tags.where((t) => t.id == filter.tagId).firstOrNull?.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          key: const ValueKey('filter-chips'),
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final option in options)
              InputChip(
                key: ValueKey('filter-chip-${option.name}'),
                label: Text(
                  _label(
                    option,
                    category: category,
                    account: account,
                    tag: tag,
                  ),
                ),
                onDeleted: () => onRemove(option),
                deleteButtonTooltipMessage: tr('Take this off'),
              ),
          ],
        ),
      ),
    );
  }
}
