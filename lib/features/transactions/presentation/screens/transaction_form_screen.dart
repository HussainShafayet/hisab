import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';
import 'package:intl/intl.dart';

/// Adds a transaction, edits the one with [editId], or adds a copy of the one
/// with [duplicateId] (same details, dated today).
class TransactionFormScreen extends ConsumerWidget {
  const TransactionFormScreen({this.editId, this.duplicateId, super.key});

  final int? editId;
  final int? duplicateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (editId: editId, duplicateId: duplicateId);
    final title = Text(editId == null ? 'Add transaction' : 'Edit transaction');

    return ref
        .watch(transactionFormDataProvider(args))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: title),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: title),
            body: ErrorView(
              message: describeError(error),
              onRetry: () => ref.invalidate(transactionFormDataProvider(args)),
            ),
          ),
          data: (data) => _TransactionForm(args: args, data: data),
        );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({required this.args, required this.data});

  final TransactionFormArgs args;
  final TransactionFormData data;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _note = TextEditingController();
  final _fee = TextEditingController();
  final _noteFocus = FocusNode();
  final _feeFocus = FocusNode();

  late TransactionType _type;
  String _expression = '';
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;
  late DateTime _day;
  bool _saving = false;
  String? _error;

  /// Confirms "Save & add another". Shown inline instead of as a snack bar,
  /// because a snack bar would cover the Save buttons.
  String? _notice;

  bool get _isEditing => widget.args.editId != null;
  TransactionFormData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    final source = _data.source;
    final options = _data.options;
    final now = ref.read(clockProvider)();

    _type = source?.type ?? TransactionType.expense;
    _expression = source == null ? '' : poishaToInput(source.amount);
    _note.text = source?.note ?? '';
    _day = dateOnly(_isEditing ? source!.date : now);

    // When copying, only reuse an account or category that can still be used.
    bool usableAccount(int? id) =>
        id != null &&
        options.accounts.any(
          (a) => a.id == id && (_isEditing || !a.isArchived),
        );
    bool usableCategory(int? id) =>
        id != null &&
        options
            .categoriesFor(_type)
            .any((c) => c.id == id && (_isEditing || !c.isArchived));

    _accountId = usableAccount(source?.accountId)
        ? source!.accountId
        : options.defaultAccountId;
    _toAccountId = usableAccount(source?.toAccountId)
        ? source!.toAccountId
        : null;
    _categoryId = usableCategory(source?.categoryId)
        ? source!.categoryId
        : null;

    _noteFocus.addListener(_onFocusChanged);
    _feeFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _note.dispose();
    _fee.dispose();
    _noteFocus.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _error = null;
      _notice = null;
      // Categories differ between income and expense.
      _categoryId = null;
    });
  }

  Future<bool> _save() async {
    final amount = evaluateAmount(_expression);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount.');
      return false;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = 'Choose an account.');
      return false;
    }
    var fee = 0;
    if (_type == TransactionType.transfer &&
        !_isEditing &&
        _fee.text.trim().isNotEmpty) {
      final parsed = parseTakaToPoisha(_fee.text);
      if (parsed == null) {
        setState(() => _error = 'Enter a valid fee, like 15 or 15.50.');
        return false;
      }
      fee = parsed;
    }

    final isTransfer = _type == TransactionType.transfer;
    final time = _isEditing ? _data.source!.date : ref.read(clockProvider)();
    final input = TransactionInput(
      type: _type,
      amount: amount,
      accountId: accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      categoryId: isTransfer ? null : _categoryId,
      date: combineDayWithTime(_day, time),
      note: _note.text,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(transactionsRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateTransaction(widget.args.editId!, input);
      } else {
        await repository.addTransaction(input, fee: fee);
      }
      return true;
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
      return false;
    }
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) context.pop();
  }

  Future<void> _saveAndAddAnother() async {
    final saved = formatPoisha(evaluateAmount(_expression) ?? 0);
    if (!await _save() || !mounted) return;
    setState(() {
      _expression = '';
      _categoryId = null;
      _saving = false;
      _notice = 'Saved $saved';
      _note.clear();
      _fee.clear();
    });
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(today) ? today : _day,
      firstDate: DateTime(2000),
      lastDate: today,
      currentDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  Future<void> _addAccountFirst() async {
    await context.push(AppRoutes.newAccount);
    ref.invalidate(transactionFormDataProvider(widget.args));
  }

  Future<void> _addCategory() async {
    await context.push(AppRoutes.newCategory(type: _type.name));
    ref.invalidate(transactionFormDataProvider(widget.args));
  }

  @override
  Widget build(BuildContext context) {
    final options = _data.options;
    final title = Text(_isEditing ? 'Edit transaction' : 'Add transaction');

    if (options.accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Add an account first',
          message: 'A transaction needs an account, like Cash or bKash.',
          action: FilledButton(
            onPressed: _addAccountFirst,
            child: const Text('Add account'),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final textFieldFocused = _noteFocus.hasFocus || _feeFocus.hasFocus;
    final amountColor = switch (_type) {
      TransactionType.income => colors.income,
      TransactionType.expense => colors.expense,
      TransactionType.transfer => theme.colorScheme.onSurface,
    };

    return Scaffold(
      appBar: AppBar(title: title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                ),
                ButtonSegment(
                  value: TransactionType.transfer,
                  label: Text('Transfer'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => _setType(selection.first),
            ),
          ),
          _AmountDisplay(expression: _expression, color: amountColor),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                key: const ValueKey('form-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _notice!,
                    key: const ValueKey('form-notice'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                if (_type == TransactionType.transfer)
                  ..._transferFields(context)
                else ...[
                  _SectionLabel(
                    _type == TransactionType.income
                        ? 'Income category'
                        : 'Expense category',
                  ),
                  _categoryChips(context),
                  const SizedBox(height: 16),
                  const _SectionLabel('Account'),
                  _accountChips(
                    selected: _accountId,
                    keyPrefix: 'account',
                    onSelected: (id) => setState(() => _accountId = id),
                  ),
                ],
                const SizedBox(height: 16),
                const _SectionLabel('Date'),
                _dateChips(context),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  focusNode: _noteFocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          if (!textFieldFocused) AmountKeypad(onKey: _onKey),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _isEditing
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveAndClose,
                        child: const Text('Save changes'),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _saveAndAddAnother,
                            child: const Text('Save & add another'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _saveAndClose,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _onKey(String key) {
    setState(() {
      _expression = applyKey(_expression, key);
      _error = null;
      _notice = null;
    });
  }

  List<Widget> _transferFields(BuildContext context) {
    final accounts = _data.options.accounts;
    if (accounts.length < 2) {
      return [
        EmptyState(
          icon: Icons.swap_horiz,
          title: 'You need two accounts',
          message: 'A transfer moves money from one account to another.',
          action: FilledButton(
            onPressed: _addAccountFirst,
            child: const Text('Add account'),
          ),
        ),
      ];
    }
    return [
      const _SectionLabel('From'),
      _accountChips(
        selected: _accountId,
        keyPrefix: 'from',
        disabledId: _toAccountId,
        onSelected: (id) => setState(() => _accountId = id),
      ),
      const SizedBox(height: 16),
      const _SectionLabel('To'),
      _accountChips(
        selected: _toAccountId,
        keyPrefix: 'to',
        disabledId: _accountId,
        onSelected: (id) => setState(() => _toAccountId = id),
      ),
      if (!_isEditing) ...[
        const SizedBox(height: 16),
        MoneyFormField(
          controller: _fee,
          focusNode: _feeFocus,
          label: 'Fee (optional)',
          isRequired: false,
          helperText: 'Saved as a separate expense on the "From" account.',
        ),
      ],
    ];
  }

  Widget _categoryChips(BuildContext context) {
    final categories = _data.options.categoriesFor(_type);
    if (categories.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: Text(
              _type == TransactionType.income
                  ? 'Add an income category'
                  : 'Add an expense category',
            ),
          ),
        ),
      );
    }

    final byId = {for (final c in categories) c.id: c};
    String labelOf(Category category) {
      final parent = byId[category.parentId];
      return parent == null
          ? category.name
          : '${parent.name} › ${category.name}';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final category in categories)
          ChoiceChip(
            key: ValueKey('category-${category.id}'),
            showCheckmark: false,
            avatar: CategoryAvatar(
              icon: category.icon,
              color: category.color,
              radius: 10,
            ),
            label: Text(
              category.isArchived
                  ? '${labelOf(category)} (archived)'
                  : labelOf(category),
            ),
            selected: _categoryId == category.id,
            onSelected: (_) => setState(() {
              _categoryId = category.id;
              _error = null;
            }),
          ),
      ],
    );
  }

  Widget _accountChips({
    required int? selected,
    required String keyPrefix,
    required ValueChanged<int> onSelected,
    int? disabledId,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final account in _data.options.accounts)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${account.id}'),
            showCheckmark: false,
            label: Text(_accountLabel(account)),
            selected: selected == account.id,
            onSelected: account.id == disabledId
                ? null
                : (_) {
                    onSelected(account.id);
                    setState(() => _error = null);
                  },
          ),
      ],
    );
  }

  String _accountLabel(Account account) =>
      account.isArchived ? '${account.name} (archived)' : account.name;

  Widget _dateChips(BuildContext context) {
    final today = dateOnly(ref.read(clockProvider)());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isOther = !isSameDay(_day, today) && !isSameDay(_day, yesterday);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          key: const ValueKey('date-today'),
          showCheckmark: false,
          label: const Text('Today'),
          selected: isSameDay(_day, today),
          onSelected: (_) => setState(() => _day = today),
        ),
        ChoiceChip(
          key: const ValueKey('date-yesterday'),
          showCheckmark: false,
          label: const Text('Yesterday'),
          selected: isSameDay(_day, yesterday),
          onSelected: (_) => setState(() => _day = yesterday),
        ),
        ChoiceChip(
          key: const ValueKey('date-other'),
          showCheckmark: false,
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            isOther
                ? DateFormat(_day.year == today.year ? 'd MMM' : 'd MMM yyyy')
                      .format(_day)
                : 'Pick date',
          ),
          selected: isOther,
          onSelected: (_) => _pickDate(),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

/// The number being typed, large, with the result below when it is a sum.
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.expression, required this.color});

  final String expression;
  final Color color;

  static final _operator = RegExp(r'[+\-×÷]');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = evaluateAmount(expression);
    final showResult = _operator.hasMatch(expression) && result != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '৳ ${expression.isEmpty ? '0' : expression.replaceAll('-', '−')}',
              key: const ValueKey('amount-display'),
              style: theme.textTheme.displaySmall?.tabular.copyWith(
                color: expression.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showResult)
            Text(
              '= ${formatPoisha(result)}',
              key: const ValueKey('amount-result'),
              style: theme.textTheme.titleMedium?.tabular.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
