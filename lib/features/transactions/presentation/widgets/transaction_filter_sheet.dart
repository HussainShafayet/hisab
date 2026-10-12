import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/date_range_picker.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Bottom sheet to choose type, category, account and date range. Pops with
/// the new [TransactionFilter] when "Apply" is pressed; the search text of
/// [initial] is kept.
class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({required this.initial, super.key});

  final TransactionFilter initial;

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  late TransactionType? _type = widget.initial.type;
  late int? _categoryId = widget.initial.categoryId;
  late int? _accountId = widget.initial.accountId;
  late DateRange? _range = widget.initial.range;

  Future<void> _pickRange() async {
    final picked = await pickDateRange(
      context,
      today: dateOnly(ref.read(clockProvider)()),
      initial: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  /// Expense categories first, then income, each category followed by what
  /// is inside it, labelled with the whole path (`Food › Restaurant`).
  List<({int id, String label})> _categoryChoices(List<Category> all) {
    final byId = {for (final c in all) c.id: c};
    return [
      for (final type in CategoryType.values.reversed)
        for (final c in flattenCategoryTree(
          buildCategoryTree(all.where((c) => c.type == type)),
        ))
          (id: c.id, label: categoryPathLabel(c, byId)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider(true));
    final categories = ref.watch(categoriesProvider(true));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: accounts.hasValue && categories.hasValue
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filter', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text('Type', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _type == null,
                          onSelected: (_) => setState(() => _type = null),
                        ),
                        for (final type in TransactionType.values)
                          ChoiceChip(
                            label: Text(switch (type) {
                              TransactionType.expense => 'Expense',
                              TransactionType.income => 'Income',
                              TransactionType.transfer => 'Transfer',
                            }),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Any category'),
                        ),
                        for (final choice in _categoryChoices(
                          categories.requireValue,
                        ))
                          DropdownMenuItem<int?>(
                            value: choice.id,
                            child: Text(choice.label),
                          ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Any account'),
                        ),
                        for (final item in accounts.requireValue)
                          DropdownMenuItem<int?>(
                            value: item.account.id,
                            child: Text(item.account.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                    const SizedBox(height: 16),
                    Text('Date range', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range),
                            onPressed: _pickRange,
                            label: Text(
                              _range == null ? 'Any date' : rangeLabel(_range!),
                            ),
                          ),
                        ),
                        if (_range != null)
                          IconButton(
                            tooltip: 'Clear date range',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _range = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pop(widget.initial.withoutSheetOptions()),
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(
                            TransactionFilter(
                              query: widget.initial.query,
                              type: _type,
                              categoryId: _categoryId,
                              categoryScope: _categoryId == null
                                  ? const {}
                                  : categoryAndDescendantIds(
                                      _categoryId!,
                                      categories.requireValue,
                                    ),
                              accountId: _accountId,
                              range: _range,
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : SizedBox(
                // Tall enough for the icon, message and Retry button.
                height: 320,
                child: accounts.hasError || categories.hasError
                    ? ErrorView(
                        message: describeError(
                          (accounts.error ?? categories.error)!,
                        ),
                        onRetry: () {
                          ref.invalidate(accountsProvider(true));
                          ref.invalidate(categoriesProvider(true));
                        },
                      )
                    : const LoadingView(),
              ),
      ),
    );
  }
}
