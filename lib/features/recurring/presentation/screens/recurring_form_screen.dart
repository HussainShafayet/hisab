import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/recurring/presentation/screens/recurring_screen.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Adds a recurring item, or edits the one with [ruleId].
class RecurringFormScreen extends ConsumerWidget {
  const RecurringFormScreen({this.ruleId, super.key});

  final int? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ruleId;
    if (id == null) return const _RecurringForm();
    final rules = ref.watch(recurringRulesProvider);
    return rules.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(tr('Edit recurring'))),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(tr('Edit recurring'))),
        body: ErrorView(message: '$error'),
      ),
      data: (list) {
        final rule = list.where((r) => r.id == id).firstOrNull;
        return rule == null
            ? Scaffold(
                appBar: AppBar(title: Text(tr('Edit recurring'))),
                body: ErrorView(
                  message: tr('This recurring item no longer exists.'),
                ),
              )
            : _RecurringForm(initial: rule);
      },
    );
  }
}

class _RecurringForm extends ConsumerStatefulWidget {
  const _RecurringForm({this.initial});

  final RecurringRule? initial;

  @override
  ConsumerState<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<_RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : poishaToInput(widget.initial!.amount),
  );
  late TransactionType _type = widget.initial?.type ?? TransactionType.expense;
  late RecurrenceFrequency _frequency =
      widget.initial?.frequency ?? RecurrenceFrequency.monthly;
  late DateTime _start =
      widget.initial?.startDate ?? dateOnly(ref.read(clockProvider)());
  late DateTime? _end = widget.initial?.endDate;
  late bool _autoAdd = widget.initial?.autoAdd ?? false;
  late bool _remind = widget.initial?.remind ?? true;
  int? _accountId;
  int? _categoryId;
  List<Category> _categories = const [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initial?.accountId;
    _categoryId = widget.initial?.categoryId;
    ref
        .read(categoriesRepositoryProvider)
        .getCategories(includeArchived: true)
        .then((all) {
          if (mounted) setState(() => _categories = all);
        });
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// The categories of the chosen type that can be picked, in tree order. The
  /// one the rule already has stays even if it was archived.
  List<Category> get _options => flattenCategoryTree(
    buildCategoryTree([
      for (final c in _categories)
        if (c.type == _type.categoryType &&
            (!c.isArchived || c.id == _categoryId))
          c,
    ]),
  );

  Future<void> _chooseCategory() async {
    final pick = await showCategoryPicker(
      context,
      title: _type == TransactionType.income
          ? tr('Income category')
          : tr('Expense category'),
      categories: _options,
      selectedId: _categoryId,
      allowAdd: false,
    );
    if (pick case CategoryPicked(:final id) when mounted) {
      setState(() => _categoryId = id);
    }
  }

  Future<void> _pickDay(
    DateTime initial,
    ValueChanged<DateTime> onPicked, {
    DateTime? first,
  }) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime(dateOnly(ref.read(clockProvider)()).year + 30),
    );
    if (day != null && mounted) setState(() => onPicked(dateOnly(day)));
  }

  Future<void> _setRemind(bool value) async {
    setState(() => _remind = value);
    if (!value) return;
    final allowed = await ref
        .read(reminderSchedulerProvider)
        .requestPermission();
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Notifications are off for Hishab. Turn them on in the phone settings to get reminders.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accountId = _accountId;
    final categoryId = _categoryId;
    if (accountId == null) {
      setState(() => _error = tr('Choose an account.'));
      return;
    }
    if (categoryId == null) {
      setState(() => _error = tr('Choose a category.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(recurringRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateRule(
          widget.initial!.id,
          title: _title.text,
          type: _type,
          amount: parseTakaToPoisha(_amount.text)!,
          accountId: accountId,
          categoryId: categoryId,
          frequency: _frequency,
          startDate: _start,
          endDate: _end,
          autoAdd: _autoAdd,
          remind: _remind,
        );
      } else {
        await repository.createRule(
          title: _title.text,
          type: _type,
          amount: parseTakaToPoisha(_amount.text)!,
          accountId: accountId,
          categoryId: categoryId,
          frequency: _frequency,
          startDate: _start,
          endDate: _end,
          autoAdd: _autoAdd,
          remind: _remind,
        );
      }
      if (mounted) context.pop();
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts =
        ref.watch(accountsProvider(false)).value ??
        const <AccountWithBalance>[];
    final byId = {for (final c in _categories) c.id: c};
    final selected = byId[_categoryId];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Edit recurring') : tr('New recurring')),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  SegmentedButton<TransactionType>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text(tr('Expense')),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text(tr('Income')),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) => setState(() {
                      _type = selection.first;
                      _categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        RecurringRepository.maxTitleLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: tr('Name'),
                      hintText: tr('House rent, salary, internet bill'),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? tr('Enter a name')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  MoneyFormField(controller: _amount, label: tr('Amount')),
                  const SizedBox(height: 16),
                  InkWell(
                    key: const ValueKey('recurring-category'),
                    onTap: _chooseCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr('Category'),
                        suffixIcon: const Icon(Icons.unfold_more),
                      ),
                      child: Row(
                        children: [
                          if (selected != null) ...[
                            CategoryAvatar(
                              icon: selected.icon,
                              color: selected.color,
                              radius: 12,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              selected == null
                                  ? tr('Choose a category')
                                  : categoryPathLabel(selected, byId),
                              key: const ValueKey('recurring-category-value'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('recurring-account-$_accountId'),
                    initialValue:
                        accounts.any((a) => a.account.id == _accountId)
                        ? _accountId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Account')),
                    items: [
                      for (final item in accounts)
                        DropdownMenuItem<int?>(
                          value: item.account.id,
                          child: Text(item.account.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('How often'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final frequency in RecurrenceFrequency.values)
                        ChoiceChip(
                          key: ValueKey('frequency-${frequency.name}'),
                          showCheckmark: false,
                          label: Text(frequencyText(frequency)),
                          selected: _frequency == frequency,
                          onSelected: (_) =>
                              setState(() => _frequency = frequency),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DayField(
                    label: tr('First due day'),
                    value: _start,
                    onPick: () => _pickDay(_start, (day) => _start = day),
                  ),
                  const SizedBox(height: 16),
                  DayField(
                    label: tr('Ends on (optional)'),
                    value: _end,
                    onPick: () => _pickDay(
                      _end ?? _start,
                      (day) => _end = day,
                      first: _start,
                    ),
                    onClear: () => setState(() => _end = null),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey('auto-add'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Add it by itself when it is due')),
                    subtitle: Text(
                      tr(
                        'Otherwise it waits in "Due now" for you to add or skip.',
                      ),
                    ),
                    value: _autoAdd,
                    onChanged: (value) => setState(() => _autoAdd = value),
                  ),
                  if (!_autoAdd)
                    SwitchListTile(
                      key: const ValueKey('remind'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('Remind me on the day')),
                      subtitle: Text(tr('A notification at 9 in the morning.')),
                      value: _remind,
                      onChanged: _setRemind,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const ValueKey('form-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _isEditing ? tr('Save changes') : tr('Add recurring'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
