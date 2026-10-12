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
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_picker_sheet.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';
import 'package:hishab/features/transactions/domain/balance_preview.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_text_formatter.dart';
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
          // The options reload after a new category or account was made from
          // the form. The form stays put (what was typed is kept) and just
          // gets the new options.
          skipLoadingOnReload: true,
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
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _fee = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _feeFocus = FocusNode();

  late TransactionType _type;
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;
  late DateTime _day;

  /// Whether the amount is typed with the calculator keypad, so it can be a
  /// sum like `1200+350`. Otherwise it is a plain number typed on the keyboard.
  bool _calculator = false;
  bool _saving = false;
  String? _error;

  /// Confirms "Save & new". Shown inline instead of as a snack bar, because a
  /// snack bar would cover the Save buttons.
  String? _notice;

  bool get _isEditing => widget.args.editId != null;
  bool get _isAdding => widget.data.source == null;
  TransactionFormData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    final source = _data.source;
    final options = _data.options;
    final now = ref.read(clockProvider)();

    _type = source?.type ?? TransactionType.expense;
    _amount.text = source == null ? '' : poishaToInput(source.amount);
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

    for (final node in [_amountFocus, _noteFocus, _feeFocus]) {
      node.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _fee.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  void _setAmountText(String text) {
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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

  /// Switches between the keyboard and the calculator keypad. Leaving the
  /// calculator turns a sum into its result, so the field holds a plain number
  /// again.
  void _toggleCalculator() {
    if (_calculator) {
      final text = _amount.text;
      if (expressionHasOperator(text)) {
        final result = evaluateAmount(text);
        if (result == null) {
          setState(() => _error = 'Check the calculation first.');
          return;
        }
        _setAmountText(result > 0 ? poishaToInput(result) : '');
      }
      setState(() {
        _calculator = false;
        _error = null;
      });
      _amountFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _calculator = true;
        _error = null;
      });
    }
  }

  void _onKey(String key) {
    setState(() {
      _setAmountText(applyKey(_amount.text, key));
      _error = null;
      _notice = null;
    });
  }

  void _onAmountChanged(String _) => setState(() {
    _error = null;
    _notice = null;
  });

  /// The keyboard's "next": on to the category, which is what comes after
  /// the amount.
  void _onAmountSubmitted(String _) {
    _amountFocus.unfocus();
    if (_type != TransactionType.transfer && _categoryId == null) {
      _chooseCategory();
    }
  }

  Future<bool> _save() async {
    final amount = evaluateAmount(_amount.text);
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

  /// Saves, then empties the form for the next one. The account, the type and
  /// the date stay, since the next one is usually alike (several things
  /// bought on the same day).
  Future<void> _saveAndAddAnother() async {
    final saved = formatPoisha(evaluateAmount(_amount.text) ?? 0);
    if (!await _save() || !mounted) return;
    setState(() {
      _setAmountText('');
      _categoryId = null;
      _saving = false;
      _notice = 'Saved $saved. Add the next one.';
      _note.clear();
      _fee.clear();
    });
    if (!_calculator) _amountFocus.requestFocus();
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
    final id = await context.push<int>(AppRoutes.newCategory(type: _type.name));
    ref.invalidate(transactionFormDataProvider(widget.args));
    // The category that was just made is the one wanted.
    if (id != null && mounted) {
      setState(() {
        _categoryId = id;
        _error = null;
      });
    }
  }

  Future<void> _chooseCategory() async {
    _amountFocus.unfocus();
    final options = _data.options;
    final pick = await showCategoryPicker(
      context,
      title: _type == TransactionType.income
          ? 'Income category'
          : 'Expense category',
      categories: options.categoriesFor(_type),
      frequentIds: options.frequentIdsFor(_type),
      selectedId: _categoryId,
    );
    if (!mounted) return;
    switch (pick) {
      case CategoryPicked(:final id):
        setState(() {
          _categoryId = id;
          _error = null;
        });
      case CategoryAddRequested():
        await _addCategory();
      case CategoryTopLevelChosen() || null:
        break;
    }
  }

  /// Opens the account sheet and hands the chosen id to [onChosen].
  Future<void> _chooseAccount({
    required String title,
    required int? selected,
    required ValueChanged<int> onChosen,
    int? disabled,
  }) async {
    _amountFocus.unfocus();
    final id = await showAccountPicker(
      context,
      title: title,
      accounts: [
        for (final account in _data.options.accounts)
          if (!account.isArchived || account.id == selected) account,
      ],
      balances: _balances(),
      selectedId: selected,
      disabledId: disabled,
    );
    if (id == null || !mounted) return;
    setState(() {
      onChosen(id);
      _error = null;
    });
  }

  Map<int, int> _balances() => {
    for (final item
        in ref.read(accountsProvider(true)).value ??
            const <AccountWithBalance>[])
      item.account.id: item.balance,
  };

  Account? _account(int? id) {
    for (final account in _data.options.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// What saving would do to the accounts, or null while the amount is empty.
  TransactionEffect? get _effect {
    final amount = evaluateAmount(_amount.text);
    final from = _accountId;
    if (amount == null || amount <= 0 || from == null) return null;
    final isTransfer = _type == TransactionType.transfer;
    return TransactionEffect(
      type: _type,
      amount: amount,
      accountId: from,
      toAccountId: isTransfer ? _toAccountId : null,
      fee: isTransfer && !_isEditing ? (parseTakaToPoisha(_fee.text) ?? 0) : 0,
    );
  }

  /// What the transaction being edited did to the balances, which the
  /// accounts already include.
  TransactionEffect? get _oldEffect {
    final source = _data.source;
    if (!_isEditing || source == null) return null;
    return TransactionEffect(
      type: source.type,
      amount: source.amount,
      accountId: source.accountId,
      toAccountId: source.toAccountId,
    );
  }

  /// The wallet card for [accountId]: its balance, and what the balance will
  /// be once this transaction is saved.
  Widget _accountCard({
    required Key key,
    required int? accountId,
    required String? caption,
    required String placeholder,
    required VoidCallback onTap,
    required Map<int, int> balances,
  }) {
    final account = _account(accountId);
    if (account == null) {
      return _ChooseTile(
        key: key,
        icon: Icons.account_balance_wallet_outlined,
        label: placeholder,
        onTap: onTap,
      );
    }
    final balance = balances[account.id];
    final effect = _effect;
    return KeyedSubtree(
      key: key,
      child: AccountCard(
        account: account,
        caption: caption,
        balance: balance,
        balanceAfter: balance == null || effect == null
            ? null
            : projectedBalance(
                current: balance,
                account: account.id,
                after: effect,
                before: _oldEffect,
              ),
        trailing: const Icon(Icons.unfold_more, color: Colors.white70),
        onTap: onTap,
      ),
    );
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
    // The balances come from their own stream. Watching it keeps the numbers
    // right while the form is open (they change after "Save & new").
    ref.watch(accountsProvider(true));
    final balances = _balances();

    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SegmentedButton<TransactionType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: TransactionType.expense,
              label: Text('Expense'),
            ),
            ButtonSegment(value: TransactionType.income, label: Text('Income')),
            ButtonSegment(
              value: TransactionType.transfer,
              label: Text('Transfer'),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) => _setType(selection.first),
        ),
      ),
      _AmountInput(
        controller: _amount,
        focusNode: _amountFocus,
        color: amountColor,
        calculator: _calculator,
        autofocus: _isAdding,
        onToggleCalculator: _toggleCalculator,
        onChanged: _onAmountChanged,
        onSubmitted: _onAmountSubmitted,
      ),
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
              Flexible(
                child: Text(
                  _notice!,
                  key: const ValueKey('form-notice'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];

    final fields = <Widget>[
      if (_type == TransactionType.transfer)
        ..._transferFields(context, balances)
      else ...[
        _categoryTile(context),
        const SizedBox(height: 12),
        _accountCard(
          key: const ValueKey('account-field'),
          accountId: _accountId,
          caption: null,
          placeholder: 'Choose account',
          balances: balances,
          onTap: () => _chooseAccount(
            title: 'Account',
            selected: _accountId,
            onChosen: (id) => _accountId = id,
          ),
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
    ];

    final keypad = _calculator && !textFieldFocused
        ? AmountKeypad(onKey: _onKey)
        : null;

    final saveBar = SafeArea(
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
                    flex: 3,
                    child: OutlinedButton(
                      key: const ValueKey('save-and-new'),
                      onPressed: _saving ? null : _saveAndAddAnother,
                      child: const Text('Save & new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveAndClose,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
      ),
    );

    // The calculator keypad and the Save buttons take about 300 dp. On a
    // short window (a phone turned sideways, split screen) nothing is left
    // for the fields, so everything scrolls together. The window height does
    // not shrink when the system keyboard opens, so typing keeps the normal
    // layout with the Save buttons above the keyboard.
    final isShort = MediaQuery.sizeOf(context).height < 520;

    return Scaffold(
      appBar: AppBar(title: title),
      body: isShort
          ? ListView(
              children: [
                ...header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields,
                  ),
                ),
                ?keypad,
                saveBar,
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      ...header,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: fields,
                        ),
                      ),
                    ],
                  ),
                ),
                ?keypad,
                saveBar,
              ],
            ),
    );
  }

  List<Widget> _transferFields(BuildContext context, Map<int, int> balances) {
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
    final canSwap = _accountId != null && _toAccountId != null;
    return [
      _accountCard(
        key: const ValueKey('from-field'),
        accountId: _accountId,
        caption: 'From',
        placeholder: 'Choose the account the money leaves',
        balances: balances,
        onTap: () => _chooseAccount(
          title: 'Move money from',
          selected: _accountId,
          disabled: _toAccountId,
          onChosen: (id) => _accountId = id,
        ),
      ),
      Align(
        child: IconButton(
          key: const ValueKey('swap-accounts'),
          tooltip: 'Swap From and To',
          icon: const Icon(Icons.swap_vert),
          onPressed: canSwap
              ? () => setState(() {
                  final from = _accountId;
                  _accountId = _toAccountId;
                  _toAccountId = from;
                })
              : null,
        ),
      ),
      _accountCard(
        key: const ValueKey('to-field'),
        accountId: _toAccountId,
        caption: 'To',
        placeholder: 'Choose the account the money goes to',
        balances: balances,
        onTap: () => _chooseAccount(
          title: 'Move money to',
          selected: _toAccountId,
          disabled: _accountId,
          onChosen: (id) => _toAccountId = id,
        ),
      ),
      if (!_isEditing) ...[
        const SizedBox(height: 16),
        MoneyFormField(
          controller: _fee,
          focusNode: _feeFocus,
          label: 'Fee (optional)',
          isRequired: false,
          onChanged: (_) => setState(() {}),
          helperText: 'Saved as an expense on the "From" account.',
        ),
      ],
    ];
  }

  Widget _categoryTile(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _data.options.categoriesFor(_type);
    final byId = {for (final c in categories) c.id: c};
    final Category? selected = byId[_categoryId];
    final caption = _type == TransactionType.income
        ? 'Income category'
        : 'Expense category';

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('category-field'),
        onTap: _chooseCategory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (selected != null)
                CategoryAvatar(icon: selected.icon, color: selected.color)
              else
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.category_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      selected == null
                          ? 'Choose a category'
                          : selected.isArchived
                          ? '${categoryPathLabel(selected, byId)} (archived)'
                          : categoryPathLabel(selected, byId),
                      key: const ValueKey('category-value'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
                semanticLabel: 'Search categories',
              ),
            ],
          ),
        ),
      ),
    );
  }

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

/// A tile for something not chosen yet, which opens its chooser.
class _ChooseTile extends StatelessWidget {
  const _ChooseTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
    );
  }
}

/// The amount: a big field typed on the keyboard, with a button beside it
/// that switches to the calculator keypad. With the calculator the field only
/// shows what the keypad builds, and the result of a sum is shown below it.
class _AmountInput extends StatelessWidget {
  const _AmountInput({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.calculator,
    required this.autofocus,
    required this.onToggleCalculator,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool calculator;
  final bool autofocus;
  final VoidCallback onToggleCalculator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  static final _operator = RegExp(r'[+\-×÷]');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineMedium?.tabular.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('amount-field'),
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    readOnly: calculator,
                    showCursor: !calculator,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: calculator
                        ? null
                        : [AmountTextFormatter()],
                    textInputAction: TextInputAction.done,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: style,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: style?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixText: '৳ ',
                      prefixStyle: style,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('calculator-toggle'),
                  tooltip: calculator
                      ? 'Type with the keyboard'
                      : 'Use the calculator',
                  isSelected: calculator,
                  icon: const Icon(Icons.calculate_outlined),
                  selectedIcon: const Icon(Icons.keyboard_alt_outlined),
                  onPressed: onToggleCalculator,
                ),
              ],
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final result = evaluateAmount(value.text);
              if (!_operator.hasMatch(value.text) || result == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '= ${formatPoisha(result)}',
                  key: const ValueKey('amount-result'),
                  style: theme.textTheme.titleMedium?.tabular.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
