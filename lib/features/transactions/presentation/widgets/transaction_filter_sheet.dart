import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/date_range_picker.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/saved_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

/// Bottom sheet to choose type, category, account, date range, amount range,
/// trip or event and feeling. Pops with the new [TransactionFilter] when
/// "Apply" is pressed; the search text of [initial] is kept.
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
  late int? _tagId = widget.initial.tagId;
  late Feeling? _feeling = widget.initial.feeling;
  late final _minAmount = TextEditingController(
    text: _amountText(widget.initial.minAmount),
  );
  late final _maxAmount = TextEditingController(
    text: _amountText(widget.initial.maxAmount),
  );
  String? _amountError;
  String? _saveError;

  static String _amountText(int? poisha) =>
      poisha == null ? '' : poishaToInput(poisha);

  @override
  void dispose() {
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  /// The amount typed in [controller]: null when empty, and [invalid] set
  /// when the text is not an amount.
  ({int? poisha, bool invalid}) _read(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return (poisha: null, invalid: false);
    final poisha = parseTakaToPoisha(text);
    if (poisha == null || poisha < 0) return (poisha: null, invalid: true);
    return (poisha: poisha, invalid: false);
  }

  /// The filter the sheet shows, or null when an amount is not valid (the
  /// reason is then on the sheet).
  TransactionFilter? _build(List<Category> categories) {
    final min = _read(_minAmount);
    final max = _read(_maxAmount);
    if (min.invalid || max.invalid) {
      setState(() => _amountError = tr('Enter the amount as a number.'));
      return null;
    }
    if (min.poisha != null && max.poisha != null && min.poisha! > max.poisha!) {
      setState(
        () => _amountError = tr('The smallest amount is above the largest.'),
      );
      return null;
    }
    return TransactionFilter(
      query: widget.initial.query,
      type: _type,
      categoryId: _categoryId,
      categoryScope: _categoryId == null
          ? const {}
          : categoryAndDescendantIds(_categoryId!, categories),
      accountId: _accountId,
      range: _range,
      minAmount: min.poisha,
      maxAmount: max.poisha,
      tagId: _tagId,
      feeling: _feeling,
    );
  }

  /// Pops with the chosen filter, unless an amount is not valid.
  void _apply(List<Category> categories) {
    final filter = _build(categories);
    if (filter != null) Navigator.of(context).pop(filter);
  }

  /// Puts a saved filter's options on the sheet. The dates stay as they are.
  void _useSaved(SavedFilter saved) {
    final f = saved.filter;
    setState(() {
      _type = f.type;
      _categoryId = f.categoryId;
      _accountId = f.accountId;
      _tagId = f.tagId;
      _feeling = f.feeling;
      _minAmount.text = _amountText(f.minAmount);
      _maxAmount.text = _amountText(f.maxAmount);
      _amountError = null;
      _saveError = null;
    });
  }

  /// Asks for a name and saves what is on the sheet, to use again.
  Future<void> _saveCurrent(List<Category> categories) async {
    final filter = _build(categories);
    if (filter == null) return;
    if (filter.activeOptions.isEmpty) {
      setState(() => _saveError = tr('Pick at least one option to save.'));
      return;
    }
    setState(() => _saveError = null);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || !mounted) return;
    await ref.read(savedFiltersRepositoryProvider).save(name, filter);
  }

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
    // The trips and events are a nice extra: the sheet does not wait for them.
    final tags = ref.watch(tagsProvider).value ?? const [];
    final saved = ref.watch(savedFiltersProvider).value ?? const [];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: accounts.hasValue && categories.hasValue
            // The options scroll; Clear all and Apply stay in view below
            // them, however many options there are and however small the
            // phone.
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Filter'), style: theme.textTheme.titleLarge),
                          if (saved.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              tr('Saved filters'),
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final filter in saved)
                                  InputChip(
                                    key: ValueKey(
                                      'saved-filter-${filter.name}',
                                    ),
                                    label: Text(filter.name),
                                    onPressed: () => _useSaved(filter),
                                    onDeleted: () => ref
                                        .read(savedFiltersRepositoryProvider)
                                        .remove(filter.name),
                                    deleteButtonTooltipMessage: tr(
                                      'Delete this saved filter',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(tr('Type'), style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(tr('All')),
                                selected: _type == null,
                                onSelected: (_) => setState(() => _type = null),
                              ),
                              for (final type in TransactionType.values)
                                ChoiceChip(
                                  label: Text(switch (type) {
                                    TransactionType.expense => tr('Expense'),
                                    TransactionType.income => tr('Income'),
                                    TransactionType.transfer => tr('Transfer'),
                                  }),
                                  selected: _type == type,
                                  onSelected: (_) =>
                                      setState(() => _type = type),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            initialValue: _categoryId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('Category'),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(tr('Any category')),
                              ),
                              for (final choice in _categoryChoices(
                                categories.requireValue,
                              ))
                                DropdownMenuItem<int?>(
                                  value: choice.id,
                                  child: Text(choice.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _categoryId = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            initialValue: _accountId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('Account'),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(tr('Any account')),
                              ),
                              for (final item in accounts.requireValue)
                                DropdownMenuItem<int?>(
                                  value: item.account.id,
                                  child: Text(item.account.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _accountId = value),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int?>(
                              key: const ValueKey('filter-tag'),
                              initialValue: tags.any((t) => t.id == _tagId)
                                  ? _tagId
                                  : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('Trip or event'),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(tr('Any trip or event')),
                                ),
                                for (final tag in tags)
                                  DropdownMenuItem<int?>(
                                    value: tag.id,
                                    child: Text(tag.name),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _tagId = value),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(tr('Amount'), style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('filter-min-amount'),
                                  controller: _minAmount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: tr('From'),
                                    prefixText: '৳ ',
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _amountError = null),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('filter-max-amount'),
                                  controller: _maxAmount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: tr('To'),
                                    prefixText: '৳ ',
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _amountError = null),
                                ),
                              ),
                            ],
                          ),
                          if (_amountError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _amountError!,
                                key: const ValueKey('filter-amount-error'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            tr('How it felt'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                key: const ValueKey('filter-feeling-any'),
                                label: Text(tr('Any')),
                                selected: _feeling == null,
                                onSelected: (_) =>
                                    setState(() => _feeling = null),
                              ),
                              for (final feeling in Feeling.values)
                                ChoiceChip(
                                  key: ValueKey(
                                    'filter-feeling-${feeling.name}',
                                  ),
                                  label: Text(switch (feeling) {
                                    Feeling.need => tr('Needed'),
                                    Feeling.want => tr('Wanted'),
                                    Feeling.regret => tr('Regret'),
                                  }),
                                  selected: _feeling == feeling,
                                  onSelected: (_) =>
                                      setState(() => _feeling = feeling),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('Date range'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.date_range),
                                  onPressed: _pickRange,
                                  label: Text(
                                    _range == null
                                        ? tr('Any date')
                                        : rangeLabel(_range!),
                                  ),
                                ),
                              ),
                              if (_range != null)
                                IconButton(
                                  tooltip: tr('Clear date range'),
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _range = null),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: const ValueKey('save-filter'),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: Text(tr('Save this filter')),
                              onPressed: () =>
                                  _saveCurrent(categories.requireValue),
                            ),
                          ),
                          if (_saveError != null)
                            Text(
                              _saveError!,
                              key: const ValueKey('save-filter-error'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(widget.initial.withoutSheetOptions()),
                        child: Text(tr('Clear all')),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const ValueKey('filter-apply'),
                        onPressed: () => _apply(categories.requireValue),
                        child: Text(tr('Apply')),
                      ),
                    ],
                  ),
                ],
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

/// Asks for the name of a filter to save.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Name this filter')),
      content: TextField(
        key: const ValueKey('saved-filter-name'),
        controller: _name,
        autofocus: true,
        maxLength: maxSavedFilterNameLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: tr('Name'),
          helperText: tr('Like "Regret over ৳500".'),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('saved-filter-save'),
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }
}
