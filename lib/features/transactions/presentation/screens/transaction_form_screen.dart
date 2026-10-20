import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/net/rate_service.dart';
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
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/tags/domain/tag.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/tags/presentation/widgets/tag_name_dialog.dart';
import 'package:hishab/features/transactions/domain/amount_calculator.dart';
import 'package:hishab/features/transactions/domain/balance_preview.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/quick_entry.dart';
import 'package:hishab/features/transactions/presentation/widgets/quick_type_bar.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_keypad.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_text_formatter.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:intl/intl.dart';

/// Adds a transaction, edits the one with [editId], or adds a copy of the one
/// with [duplicateId] (same details, dated today). With [payCardId] it starts
/// as a transfer to that credit card, for [payAmount] (the bill).
class TransactionFormScreen extends ConsumerWidget {
  const TransactionFormScreen({
    this.editId,
    this.duplicateId,
    this.payCardId,
    this.payAmount,
    this.payUsd,
    this.prefillAmount,
    this.prefillNote,
    super.key,
  });

  final int? editId;
  final int? duplicateId;
  final int? payCardId;
  final int? payAmount;

  /// The dollars still due on the card, in US cents, for "Pay bill".
  final int? payUsd;

  /// An amount (poisha) and a note to start a new transaction with, like the
  /// total of the bazar list.
  final int? prefillAmount;
  final String? prefillNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (editId: editId, duplicateId: duplicateId);
    final title = Text(
      editId == null ? tr('Add transaction') : tr('Edit transaction'),
    );

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
          data: (data) => _TransactionForm(
            args: args,
            data: data,
            payCardId: payCardId,
            payAmount: payAmount,
            payUsd: payUsd,
            prefillAmount: prefillAmount,
            prefillNote: prefillNote,
          ),
        );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({
    required this.args,
    required this.data,
    this.payCardId,
    this.payAmount,
    this.payUsd,
    this.prefillAmount,
    this.prefillNote,
  });

  final TransactionFormArgs args;
  final TransactionFormData data;
  final int? payCardId;
  final int? payAmount;
  final int? payUsd;
  final int? prefillAmount;
  final String? prefillNote;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _fee = TextEditingController();

  /// The dollars behind a credit card entry (see [_dollarCard]).
  final _usd = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _feeFocus = FocusNode();
  final _usdFocus = FocusNode();

  late TransactionType _type;
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;

  /// The trip or event of an income or expense.
  int? _tagId;

  /// How an expense felt afterwards, if the person says.
  Feeling? _feeling;
  late DateTime _day;

  /// Whether the amount is typed with the calculator keypad, so it can be a
  /// sum like `1200+350`. Otherwise it is a plain number typed on the keyboard.
  bool _calculator = false;

  /// Whether the calculator keypad is on screen. It opens for a new entry and
  /// closes when a category, an account or the date is being chosen, so the
  /// rest of the form is in view; tapping the amount opens it again.
  bool _keypadOpen = false;

  /// Whether the extra fields (trip or event, feeling) are shown.
  bool _moreOpen = false;
  bool _saving = false;
  String? _error;

  /// Fetching today's dollar rate, and what it said.
  bool _fetchingRate = false;
  String? _rateNote;

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
    // A new transaction starts with the calculator when Settings say so.
    _calculator =
        _isAdding &&
        ref.read(preferencesProvider).amountEntry == AmountEntry.calculator;
    _keypadOpen = _calculator;
    _amount.text = source == null ? '' : poishaToInput(source.amount);
    _note.text = source?.note ?? '';
    _tagId = source?.tagId;
    _feeling = source?.feeling;
    _moreOpen = _tagId != null || _feeling != null;
    final usd = source?.usdAmount;
    _usd.text = usd == null ? '' : poishaToInput(usd);
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

    // "Pay bill" on a credit card: a transfer into the card.
    final card = widget.payCardId;
    if (_isAdding && card != null && usableAccount(card)) {
      _type = TransactionType.transfer;
      _toAccountId = card;
      if (_accountId == card) {
        _accountId = options.accounts
            .where((a) => a.id != card && !a.isArchived)
            .firstOrNull
            ?.id;
      }
      final owed = widget.payAmount;
      if (owed != null && owed > 0) _amount.text = poishaToInput(owed);
      final dollars = widget.payUsd;
      if (dollars != null && dollars > 0) _usd.text = poishaToInput(dollars);
    }

    final prefill = widget.prefillAmount;
    if (_isAdding && card == null && prefill != null && prefill > 0) {
      _amount.text = poishaToInput(prefill);
    }
    final prefillNote = widget.prefillNote;
    if (_isAdding && prefillNote != null) _note.text = prefillNote;

    for (final node in [_amountFocus, _noteFocus, _feeFocus, _usdFocus]) {
      node.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() => setState(() {});

  /// Fills the form with what the quick-type line understood. What it did not
  /// understand stays as it was.
  void _applyQuick(QuickEntry entry) {
    setState(() {
      _categoryId =
          entry.category?.id ?? (entry.type == _type ? _categoryId : null);
      _type = entry.type;
      final account = entry.account;
      if (account != null) _accountId = account.id;
      final amount = entry.amount;
      if (amount != null) _setAmountText(poishaToInput(amount));
      if (entry.note.isNotEmpty) _note.text = entry.note;
      final day = entry.day;
      if (day != null) _day = day;
      _error = null;
      _notice = tr('Filled in. Check it and save.');
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _fee.dispose();
    _usd.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    _feeFocus.dispose();
    _usdFocus.dispose();
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
          setState(() => _error = tr('Check the calculation first.'));
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
        _keypadOpen = true;
        _error = null;
      });
    }
  }

  void _openKeypad() {
    if (!_calculator || _keypadOpen) return;
    FocusScope.of(context).unfocus();
    setState(() => _keypadOpen = true);
  }

  void _closeKeypad() {
    if (_keypadOpen) setState(() => _keypadOpen = false);
  }

  /// Takes [id] as the category. A new entry then has its amount, so the
  /// keypad makes room for the rest of the form.
  void _setCategory(int id) {
    setState(() {
      _categoryId = id;
      _error = null;
      if (_isAdding) _keypadOpen = false;
    });
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
      setState(() => _error = tr('Enter an amount.'));
      return false;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = tr('Choose an account.'));
      return false;
    }
    var fee = 0;
    if (_type == TransactionType.transfer &&
        !_isEditing &&
        _fee.text.trim().isNotEmpty) {
      final parsed = parseTakaToPoisha(_fee.text);
      if (parsed == null) {
        setState(() => _error = tr('Enter a valid fee, like 15 or 15.50.'));
        return false;
      }
      fee = parsed;
    }

    int? usd;
    if (_dollarCard != null && _usd.text.trim().isNotEmpty) {
      usd = parseTakaToPoisha(_usd.text);
      if (usd == null || usd <= 0) {
        setState(
          () => _error = tr('Enter a valid dollar amount, like 25 or 25.50.'),
        );
        return false;
      }
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
      usdAmount: usd,
      tagId: isTransfer ? null : _tagId,
      feeling: _type == TransactionType.expense ? _feeling : null,
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
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
      return false;
    }
  }

  /// Opens the "Add several" screen. When it saved something the single form
  /// has nothing left to do, so it closes too.
  Future<void> _addSeveral() async {
    final saved = await context.push<bool>(AppRoutes.addSeveral);
    if (saved == true && mounted) context.pop(true);
  }

  Future<void> _saveAndClose() async {
    // The screen that opened the form can tell it was saved (true).
    if (await _save() && mounted) context.pop(true);
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
      _notice = tr('Saved {amount}. Add the next one.', {'amount': saved});
      _note.clear();
      _fee.clear();
      _usd.clear();
    });
    if (!_calculator) _amountFocus.requestFocus();
  }

  Future<void> _pickDate() async {
    _closeKeypad();
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
    _closeKeypad();
    final options = _data.options;
    final pick = await showCategoryPicker(
      context,
      title: _type == TransactionType.income
          ? tr('Income category')
          : tr('Expense category'),
      categories: options.categoriesFor(_type),
      frequentIds: options.frequentIdsFor(_type),
      selectedId: _categoryId,
    );
    if (!mounted) return;
    switch (pick) {
      case CategoryPicked(:final id):
        _setCategory(id);
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
    _closeKeypad();
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

  /// The credit card this entry is spent on, refunded to, or paid into, which
  /// is the only case where the dollars can be entered.
  Account? get _dollarCard {
    final id = _type == TransactionType.transfer ? _toAccountId : _accountId;
    final account = _account(id);
    return account != null && account.isCreditCard ? account : null;
  }

  /// The label and hint of the dollar field, by what is being entered.
  ({String label, String? hint}) get _dollarTexts {
    switch (_type) {
      case TransactionType.income:
        return (
          label: tr('Refunded in dollars (optional)'),
          hint: tr('Lowers the dollars you owe on the card.'),
        );
      case TransactionType.transfer:
        return (
          label: tr('Dollars this payment clears (optional)'),
          hint: tr('Lowers the dollars you owe on the card.'),
        );
      case TransactionType.expense:
        final amount = evaluateAmount(_amount.text);
        final usd = parseTakaToPoisha(_usd.text);
        final rate = amount == null || usd == null || usd <= 0
            ? null
            : amount / usd;
        return (
          label: tr('Spent in dollars (optional)'),
          hint: rate == null
              ? tr('The taka above stays what the bank charges.')
              : tr('About {rate} for each dollar.', {
                  'rate': localizeDigits('৳${rate.toStringAsFixed(2)}'),
                }),
        );
    }
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
    bool stacked = false,
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
        compact: true,
        stacked: stacked,
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
    final title = Text(
      _isEditing ? tr('Edit transaction') : tr('Add transaction'),
    );

    if (options.accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: tr('Add an account first'),
          message: tr('Pick an account, like Cash or bKash.'),
          action: FilledButton(
            onPressed: _addAccountFirst,
            child: Text(tr('Add account')),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colors = context.financeColors;
    final textFieldFocused =
        _noteFocus.hasFocus || _feeFocus.hasFocus || _usdFocus.hasFocus;
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
      if (_isAdding && widget.payCardId == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: QuickTypeBar(
            options: options,
            onApply: _applyQuick,
            today: dateOnly(ref.read(clockProvider)()),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SegmentedButton<TransactionType>(
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
            ButtonSegment(
              value: TransactionType.transfer,
              label: Text(tr('Transfer')),
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
        autofocus: _isAdding && !_calculator,
        keypadClosed: _calculator && !_keypadOpen,
        onTap: _openKeypad,
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
        _categoryArea(context),
        const SizedBox(height: 12),
        _accountCard(
          key: const ValueKey('account-field'),
          accountId: _accountId,
          caption: null,
          placeholder: tr('Choose account'),
          balances: balances,
          onTap: () => _chooseAccount(
            title: tr('Account'),
            selected: _accountId,
            onChosen: (id) => _accountId = id,
          ),
        ),
      ],
      if (_dollarCard != null) ...[
        const SizedBox(height: 16),
        MoneyFormField(
          key: const ValueKey('usd-field'),
          controller: _usd,
          focusNode: _usdFocus,
          label: _dollarTexts.label,
          prefix: '\$ ',
          isRequired: false,
          onChanged: (_) => setState(() {
            _error = null;
            _notice = null;
          }),
          helperText: _dollarTexts.hint,
        ),
        if (_type == TransactionType.expense)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('usd-rate'),
              onPressed: _fetchingRate ? null : _useTodaysRate,
              icon: _fetchingRate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(tr('Use today\'s rate')),
            ),
          ),
        if (_rateNote != null && _type == TransactionType.expense)
          Text(
            _rateNote!,
            key: const ValueKey('usd-rate-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
      const SizedBox(height: 16),
      _SectionLabel(tr('Date')),
      _dateChips(context),
      const SizedBox(height: 16),
      TextField(
        controller: _note,
        focusNode: _noteFocus,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: tr('Note')),
      ),
      // A transfer only has a fee to add, and only when it is new.
      if (_type != TransactionType.transfer ||
          (!_isEditing && _data.options.accounts.length >= 2))
        _moreDetails(context),
    ];

    final keypad = _calculator && _keypadOpen && !textFieldFocused
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
                  child: Text(tr('Save changes')),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      key: const ValueKey('save-and-new'),
                      onPressed: _saving ? null : _saveAndAddAnother,
                      child: Text(tr('Save & new')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveAndClose,
                      child: Text(tr('Save')),
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
      appBar: AppBar(
        title: title,
        actions: [
          const HelpButton('transactions'),
          if (_isAdding &&
              widget.payCardId == null &&
              widget.prefillAmount == null)
            IconButton(
              key: const ValueKey('add-several'),
              tooltip: tr('Add several'),
              icon: const Icon(Icons.playlist_add),
              onPressed: _addSeveral,
            ),
        ],
      ),
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
          title: tr('You need two accounts'),
          message: tr('Move money from one account to another.'),
          action: FilledButton(
            onPressed: _addAccountFirst,
            child: Text(tr('Add account')),
          ),
        ),
      ];
    }
    final canSwap = _accountId != null && _toAccountId != null;
    return [
      Stack(
        alignment: Alignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _accountCard(
                  key: const ValueKey('from-field'),
                  accountId: _accountId,
                  caption: tr('From'),
                  placeholder: tr('From'),
                  stacked: true,
                  balances: balances,
                  onTap: () => _chooseAccount(
                    title: tr('Move money from'),
                    selected: _accountId,
                    disabled: _toAccountId,
                    onChosen: (id) => _accountId = id,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountCard(
                  key: const ValueKey('to-field'),
                  accountId: _toAccountId,
                  caption: tr('To'),
                  placeholder: tr('To'),
                  stacked: true,
                  balances: balances,
                  onTap: () => _chooseAccount(
                    title: tr('Move money to'),
                    selected: _toAccountId,
                    disabled: _accountId,
                    onChosen: (id) => _toAccountId = id,
                  ),
                ),
              ),
            ],
          ),
          IconButton.filledTonal(
            key: const ValueKey('swap-accounts'),
            tooltip: tr('Swap From and To'),
            icon: const Icon(Icons.swap_horiz),
            onPressed: canSwap
                ? () => setState(() {
                    final from = _accountId;
                    _accountId = _toAccountId;
                    _toAccountId = from;
                  })
                : null,
          ),
        ],
      ),
    ];
  }

  /// The category: while none is chosen and some are used often, a grid of
  /// those (and "All"), one tap each; otherwise the tile with the chosen one.
  Widget _categoryArea(BuildContext context) {
    final options = _data.options;
    final frequent = options.frequentIdsFor(_type);
    if (_categoryId != null || frequent.isEmpty) return _categoryTile(context);

    final byId = {for (final c in options.categoriesFor(_type)) c.id: c};
    final shown = [
      for (final id in frequent)
        if (byId[id] != null) byId[id]!,
    ];
    if (shown.isEmpty) return _categoryTile(context);

    final theme = Theme.of(context);
    Widget tile({
      required Key key,
      required Widget avatar,
      required String label,
      required VoidCallback onTap,
      bool dashed = false,
    }) => Material(
      color: dashed
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: dashed
            ? BorderSide(color: theme.colorScheme.outline)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          _type == TransactionType.income
              ? tr('Income category')
              : tr('Expense category'),
        ),
        GridView(
          key: const ValueKey('quick-categories'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 76,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          children: [
            for (final category in shown)
              tile(
                key: ValueKey('quick-category-${category.id}'),
                avatar: CategoryAvatar(
                  icon: category.icon,
                  color: category.color,
                  radius: 16,
                ),
                label: category.name,
                onTap: () => _setCategory(category.id),
              ),
            tile(
              key: const ValueKey('category-field'),
              dashed: true,
              avatar: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              label: tr('All'),
              onTap: _chooseCategory,
            ),
          ],
        ),
      ],
    );
  }

  /// The trip or event and the feeling, folded away: most entries have
  /// neither.
  Widget _moreDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const ValueKey('more-details'),
          onPressed: () => setState(() => _moreOpen = !_moreOpen),
          icon: Icon(_moreOpen ? Icons.expand_less : Icons.expand_more),
          iconAlignment: IconAlignment.end,
          label: Text(_moreOpen ? tr('Fewer details') : tr('More details')),
        ),
        if (_moreOpen)
          if (_type == TransactionType.transfer)
            MoneyFormField(
              controller: _fee,
              focusNode: _feeFocus,
              label: tr('Fee (optional)'),
              isRequired: false,
              onChanged: (_) => setState(() {}),
              helperText: tr('Saved as an expense on the "From" account.'),
            )
          else ...[
            _tagSection(context),
            if (_type == TransactionType.expense) ...[
              const SizedBox(height: 16),
              _feelingSection(),
            ],
          ],
      ],
    );
  }

  /// Three chips for how an expense felt. Tapping the one chosen clears it.
  Widget _feelingSection() {
    Widget chip(Feeling feeling, IconData icon, String label) => ChoiceChip(
      key: ValueKey('feeling-${feeling.name}'),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: _feeling == feeling,
      showCheckmark: false,
      onSelected: (on) => setState(() => _feeling = on ? feeling : null),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(tr('How did it feel? (optional)')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            chip(Feeling.need, Icons.check_circle_outline, tr('Needed')),
            chip(Feeling.want, Icons.favorite_border, tr('Wanted')),
            chip(
              Feeling.regret,
              Icons.sentiment_dissatisfied_outlined,
              tr('Regret'),
            ),
          ],
        ),
      ],
    );
  }

  /// How many tags are shown as chips before the rest are left out. The one
  /// chosen is always shown.
  static const _shownTags = 8;

  /// Chips for the trips and events, to tag an income or expense with one.
  Widget _tagSection(BuildContext context) {
    final all = ref.watch(tagsProvider).value ?? const <Tag>[];
    final shown = [
      for (final tag in all.take(_shownTags)) tag,
      for (final tag in all.skip(_shownTags))
        if (tag.id == _tagId) tag,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(tr('Trip or event (optional)')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tag in shown)
              FilterChip(
                key: ValueKey('tag-${tag.id}'),
                label: Text(tag.name),
                selected: _tagId == tag.id,
                onSelected: (on) => setState(() => _tagId = on ? tag.id : null),
              ),
            ActionChip(
              key: const ValueKey('new-tag'),
              avatar: const Icon(Icons.add, size: 18),
              label: Text(tr('New tag')),
              onPressed: _newTag,
            ),
          ],
        ),
      ],
    );
  }

  /// Looks up today's market rate for a dollar. With the taka amount still
  /// empty it fills it in from the dollars; the bank's own rate is what is
  /// charged, so the figure is only a start.
  Future<void> _useTodaysRate() async {
    final usd = parseTakaToPoisha(_usd.text);
    if (usd == null || usd <= 0) {
      setState(() => _error = tr('Enter the dollar amount first.'));
      return;
    }
    setState(() {
      _fetchingRate = true;
      _error = null;
    });
    try {
      final rate = await ref.read(rateServiceProvider).usdToBdt();
      if (!mounted) return;
      setState(() {
        if (_amount.text.trim().isEmpty) {
          _setAmountText(poishaToInput((usd * rate).round()));
        }
        _rateNote = tr(
          'The market rate today is about {rate} for each dollar. Your '
          'bank\'s rate may differ.',
          {'rate': localizeDigits('৳${rate.toStringAsFixed(2)}')},
        );
      });
    } on RateException catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
  }

  Future<void> _newTag() async {
    int? madeId;
    final saved = await showTagNameDialog(
      context,
      title: tr('New trip or event'),
      onSave: (name) async {
        madeId = await ref.read(tagsRepositoryProvider).createTag(name);
      },
    );
    if (saved == true && madeId != null && mounted) {
      setState(() => _tagId = madeId);
    }
  }

  Widget _categoryTile(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _data.options.categoriesFor(_type);
    final byId = {for (final c in categories) c.id: c};
    final Category? selected = byId[_categoryId];
    final caption = _type == TransactionType.income
        ? tr('Income category')
        : tr('Expense category');

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
                          ? tr('Choose a category')
                          : selected.isArchived
                          ? tr('{name} (archived)', {
                              'name': categoryPathLabel(selected, byId),
                            })
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
              if (selected != null)
                Text(
                  tr('Change'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: tr('Search categories'),
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
          label: Text(tr('Today')),
          selected: isSameDay(_day, today),
          onSelected: (_) => setState(() => _day = today),
        ),
        ChoiceChip(
          key: const ValueKey('date-yesterday'),
          showCheckmark: false,
          label: Text(tr('Yesterday')),
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
                : tr('Pick date'),
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
    required this.keypadClosed,
    required this.onTap,
    required this.autofocus,
    required this.onToggleCalculator,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool calculator;

  /// The calculator is on but its keypad is put away: show how to bring it
  /// back.
  final bool keypadClosed;

  /// A tap on the amount, which opens the keypad again.
  final VoidCallback onTap;
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
                    onTap: onTap,
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
                if (keypadClosed)
                  TextButton.icon(
                    key: const ValueKey('amount-edit'),
                    onPressed: onTap,
                    icon: const Icon(Icons.dialpad, size: 18),
                    label: Text(tr('Edit')),
                  ),
                IconButton(
                  key: const ValueKey('calculator-toggle'),
                  tooltip: calculator
                      ? tr('Type with the keyboard')
                      : tr('Use the calculator'),
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
