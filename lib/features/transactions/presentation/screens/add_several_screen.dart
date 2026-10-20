import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_picker_sheet.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/batch_rows.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/amount_text_formatter.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:intl/intl.dart';

const TransactionFormArgs _args = (editId: null, duplicateId: null);

/// Enters several transactions (any mix of expenses, incomes and transfers)
/// and saves them with one tap. Each row is saved on its own: a row with a
/// mistake stays here with its reason, the others are saved and leave.
class AddSeveralScreen extends ConsumerWidget {
  const AddSeveralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = Text(tr('Add several'));

    return ref
        .watch(transactionFormDataProvider(_args))
        .when(
          // The options reload after a category or account was made from here.
          // The rows stay put (what was typed is kept).
          skipLoadingOnReload: true,
          loading: () => Scaffold(
            appBar: AppBar(title: title),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: title),
            body: ErrorView(
              message: describeError(error),
              onRetry: () => ref.invalidate(transactionFormDataProvider(_args)),
            ),
          ),
          data: (data) => data.options.accounts.isEmpty
              ? Scaffold(
                  appBar: AppBar(title: title),
                  body: EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: tr('Add an account first'),
                    message: tr('Pick an account, like Cash or bKash.'),
                    action: FilledButton(
                      onPressed: () async {
                        await context.push(AppRoutes.newAccount);
                        ref.invalidate(transactionFormDataProvider(_args));
                      },
                      child: Text(tr('Add account')),
                    ),
                  ),
                )
              : _AddSeveralForm(options: data.options),
        );
  }
}

/// One row as it is being filled in.
class _Row {
  _Row({required this.type, this.accountId, this.toAccountId});

  final key = UniqueKey();
  final amount = TextEditingController();
  final note = TextEditingController();
  TransactionType type;
  int? accountId;
  int? toAccountId;
  int? categoryId;

  /// Why the row could not be saved, shown under it.
  String? error;

  BatchDraft get draft => BatchDraft(
    type: type,
    amountText: amount.text,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: note.text,
  );

  void dispose() {
    amount.dispose();
    note.dispose();
  }
}

class _AddSeveralForm extends ConsumerStatefulWidget {
  const _AddSeveralForm({required this.options});

  final AddTransactionOptions options;

  @override
  ConsumerState<_AddSeveralForm> createState() => _AddSeveralFormState();
}

class _AddSeveralFormState extends ConsumerState<_AddSeveralForm> {
  final _scroll = ScrollController();
  final _rows = <_Row>[];

  /// Rows that left the screen. Their controllers are disposed with the screen,
  /// since the last frame may still draw them.
  final _retired = <_Row>[];
  late DateTime _day;
  bool _saving = false;

  /// What the last save did, while some rows are still to be fixed.
  String? _banner;

  /// What pasting lines did. It stays on the screen, since a message at the
  /// bottom would cover the Save button.
  String? _notice;

  AddTransactionOptions get _options => widget.options;

  @override
  void initState() {
    super.initState();
    _day = dateOnly(ref.read(clockProvider)());
    _rows.add(
      _Row(type: TransactionType.expense, accountId: _options.defaultAccountId),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final row in [..._rows, ..._retired]) {
      row.dispose();
    }
    super.dispose();
  }

  String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.expense => tr('Expense'),
    TransactionType.income => tr('Income'),
    TransactionType.transfer => tr('Transfer'),
  };

  /// A new row starts like the one before it, since the next one is usually
  /// alike.
  void _addRow() {
    final last = _rows.last;
    setState(() {
      _rows.add(
        _Row(
          type: last.type,
          accountId: last.accountId,
          toAccountId: last.toAccountId,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Asks for a block of lines and makes a row of each. Blank rows give way;
  /// the rest stay.
  Future<void> _pasteLines() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _PasteDialog(),
    );
    if (text == null || !mounted) return;
    final drafts = draftsFromLines(
      text,
      _options,
      defaultAccountId: _rows.last.accountId ?? _options.defaultAccountId,
    );
    if (drafts.isEmpty) {
      setState(
        () => _notice = tr('Nothing to add: write one entry on each line.'),
      );
      return;
    }
    setState(() {
      for (final blank in _rows.where((r) => r.draft.isBlank).toList()) {
        _rows.remove(blank);
        _retired.add(blank);
      }
      for (final draft in drafts) {
        final row = _Row(type: draft.type, accountId: draft.accountId)
          ..categoryId = draft.categoryId;
        row.amount.text = draft.amountText;
        row.note.text = draft.note;
        _rows.add(row);
      }
      _banner = null;
      _notice = plural(
        drafts.length,
        'Added 1 row. Check it and save.',
        'Added {n} rows. Check them and save.',
      );
    });
  }

  void _removeRow(_Row row) {
    setState(() {
      _rows.remove(row);
      _retired.add(row);
    });
  }

  void _setType(_Row row, TransactionType type) {
    setState(() {
      row.type = type;
      row.error = null;
      // Categories differ between income and expense.
      row.categoryId = null;
    });
  }

  void _edited(_Row row) => setState(() => row.error = null);

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

  Map<int, int> _balances() => {
    for (final item
        in ref.read(accountsProvider(true)).value ??
            const <AccountWithBalance>[])
      item.account.id: item.balance,
  };

  Account? _account(int? id) {
    for (final account in _options.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<void> _chooseAccount(_Row row, {required bool second}) async {
    FocusScope.of(context).unfocus();
    final isTransfer = row.type == TransactionType.transfer;
    final selected = second ? row.toAccountId : row.accountId;
    final id = await showAccountPicker(
      context,
      title: !isTransfer
          ? tr('Account')
          : second
          ? tr('Move money to')
          : tr('Move money from'),
      accounts: [
        for (final account in _options.accounts)
          if (!account.isArchived || account.id == selected) account,
      ],
      balances: _balances(),
      selectedId: selected,
      disabledId: isTransfer
          ? (second ? row.accountId : row.toAccountId)
          : null,
    );
    if (id == null || !mounted) return;
    setState(() {
      if (second) {
        row.toAccountId = id;
      } else {
        row.accountId = id;
      }
      row.error = null;
    });
  }

  Future<void> _chooseCategory(_Row row) async {
    FocusScope.of(context).unfocus();
    final pick = await showCategoryPicker(
      context,
      title: row.type == TransactionType.income
          ? tr('Income category')
          : tr('Expense category'),
      categories: _options.categoriesFor(row.type),
      frequentIds: _options.frequentIdsFor(row.type),
      selectedId: row.categoryId,
    );
    if (!mounted) return;
    switch (pick) {
      case CategoryPicked(:final id):
        setState(() {
          row.categoryId = id;
          row.error = null;
        });
      case CategoryAddRequested():
        final id = await context.push<int>(
          AppRoutes.newCategory(type: row.type.name),
        );
        ref.invalidate(transactionFormDataProvider(_args));
        // The category that was just made is the one wanted.
        if (id != null && mounted) {
          setState(() {
            row.categoryId = id;
            row.error = null;
          });
        }
      case CategoryTopLevelChosen() || null:
        break;
    }
  }

  String _bannerFor({required int saved, required int failed}) => saved == 0
      ? plural(failed, '1 row needs fixing', '{n} rows need fixing')
      : tr('{saved} saved, {failed} left to fix', {
          'saved': saved,
          'failed': failed,
        });

  /// Saves every row that is filled in, one after the other. Saved rows leave
  /// the screen; a row with a mistake stays, with its reason.
  Future<void> _save() async {
    final date = combineDayWithTime(_day, ref.read(clockProvider)());
    final pending = <_Row>[];
    final inputs = <TransactionInput>[];
    var failed = 0;
    setState(() {
      _banner = null;
      _notice = null;
      for (final row in _rows) {
        row.error = null;
        final draft = row.draft;
        if (draft.isBlank) continue;
        final parsed = parseBatchDraft(draft, date);
        final input = parsed.input;
        if (input == null) {
          row.error = parsed.error;
          failed++;
        } else {
          pending.add(row);
          inputs.add(input);
        }
      }
      if (inputs.isEmpty) _banner = _bannerFor(saved: 0, failed: failed);
    });
    if (inputs.isEmpty) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final List<String?> results;
    try {
      results = await ref
          .read(transactionsRepositoryProvider)
          .addTransactions(inputs);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showError(describeError(e));
      }
      return;
    }
    if (!mounted) return;

    var saved = 0;
    setState(() {
      for (var i = 0; i < pending.length; i++) {
        final row = pending[i];
        final error = results[i];
        if (error == null) {
          saved++;
          _rows.remove(row);
          _retired.add(row);
        } else {
          row.error = error;
          failed++;
        }
      }
      _saving = false;
      if (failed > 0) _banner = _bannerFor(saved: saved, failed: failed);
    });
    if (failed == 0) {
      messenger.showMessage(
        plural(saved, '1 transaction saved', '{n} transactions saved'),
      );
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The balances come from their own stream; the account sheet reads them.
    ref.watch(accountsProvider(true));
    final count = _rows.where((row) => !row.draft.isBlank).length;
    final saveLabel = count > 1 ? tr('Save all {n}', {'n': count}) : tr('Save');

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Add several')),
        actions: [
          IconButton(
            key: const ValueKey('paste-lines'),
            tooltip: tr('Paste lines'),
            icon: const Icon(Icons.content_paste_go_outlined),
            onPressed: _saving ? null : _pasteLines,
          ),
          const HelpButton('transactions'),
        ],
      ),
      body: Column(
        children: [
          if (_notice != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _notice!,
                key: const ValueKey('paste-notice'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          if (_banner != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _banner!,
                key: const ValueKey('batch-banner'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  tr(
                    'Each row is saved on its own. A row with a mistake stays here for you to fix.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _dateChips(),
                const SizedBox(height: 8),
                for (var i = 0; i < _rows.length; i++) _rowCard(i, _rows[i]),
                OutlinedButton.icon(
                  key: const ValueKey('add-row'),
                  onPressed: _saving ? null : _addRow,
                  icon: const Icon(Icons.add),
                  label: Text(tr('Add row')),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-all'),
                  onPressed: count == 0 || _saving ? null : _save,
                  child: Text(saveLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChips() {
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
                ? localizeDigits(
                    DateFormat(_day.year == today.year ? 'd MMM' : 'd MMM yyyy')
                        .format(_day),
                  )
                : tr('Pick date'),
          ),
          selected: isOther,
          onSelected: (_) => _pickDate(),
        ),
      ],
    );
  }

  /// A small tile for something to choose, which opens its chooser.
  Widget _tile({
    required Key key,
    required IconData icon,
    required String label,
    required bool chosen,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      key: key,
      onPressed: _saving ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: chosen
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
    );
  }

  Widget _accountTile(int index, _Row row, {required bool second}) {
    final isTransfer = row.type == TransactionType.transfer;
    final account = _account(second ? row.toAccountId : row.accountId);
    final placeholder = !isTransfer
        ? tr('Choose account')
        : second
        ? tr('To')
        : tr('From');
    return _tile(
      key: ValueKey(
        isTransfer
            ? 'row-${second ? 'to' : 'from'}-$index'
            : 'row-account-$index',
      ),
      icon: Icons.account_balance_wallet_outlined,
      label: account?.name ?? placeholder,
      chosen: account != null,
      onTap: () => _chooseAccount(row, second: second),
    );
  }

  Widget _categoryTile(int index, _Row row) {
    final id = row.categoryId;
    final name = id == null
        ? null
        : _options
              .categoriesFor(row.type)
              .where((c) => c.id == id)
              .firstOrNull
              ?.name;
    return _tile(
      key: ValueKey('row-category-$index'),
      icon: Icons.category_outlined,
      label: name ?? tr('Choose a category'),
      chosen: name != null,
      onTap: () => _chooseCategory(row),
    );
  }

  Widget _rowCard(int index, _Row row) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final amountColor = switch (row.type) {
      TransactionType.income => colors.income,
      TransactionType.expense => colors.expense,
      TransactionType.transfer => theme.colorScheme.onSurface,
    };

    return Card(
      key: row.key,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Row {number} · {type}', {
                      'number': index + 1,
                      'type': _typeLabel(row.type),
                    }),
                    key: ValueKey('row-title-$index'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    key: ValueKey('row-remove-$index'),
                    tooltip: tr('Remove row'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => _removeRow(row),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final type in TransactionType.values)
                  ButtonSegment(value: type, label: Text(_typeLabel(type))),
              ],
              selected: {row.type},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => _setType(row, selection.first),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('row-amount-$index'),
              controller: row.amount,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountTextFormatter()],
              onChanged: (_) => _edited(row),
              style: theme.textTheme.titleLarge?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: tr('Amount'),
                hintText: '0',
                prefixText: '৳ ',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (row.type == TransactionType.transfer)
              Row(
                children: [
                  Expanded(child: _accountTile(index, row, second: false)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 18),
                  ),
                  Expanded(child: _accountTile(index, row, second: true)),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _categoryTile(index, row)),
                  const SizedBox(width: 8),
                  Expanded(child: _accountTile(index, row, second: false)),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('row-note-$index'),
              controller: row.note,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _edited(row),
              decoration: InputDecoration(labelText: tr('Note'), isDense: true),
            ),
            if (row.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  row.error!,
                  key: ValueKey('row-error-$index'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks for lines of text, one entry on each, like `rickshaw 50` or `lunch 120
/// bkash`, typed or pasted.
class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text;
    if (pasted == null || pasted.isEmpty || !mounted) return;
    final current = _text.text;
    _text.text = current.isEmpty ? pasted : '$current\n$pasted';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Paste lines')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'One entry on each line, like "rickshaw 50", "lunch 120 bkash" '
              'or "+salary 30k". A row is made of each.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('paste-field'),
            controller: _text,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'rickshaw 50\nlunch 120 bkash\n+salary 30k',
            ),
            onChanged: (_) => setState(() {}),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('paste-clipboard'),
              icon: const Icon(Icons.content_paste),
              label: Text(tr('Paste from the clipboard')),
              onPressed: _paste,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('paste-add'),
          onPressed: _text.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _text.text),
          child: Text(tr('Add rows')),
        ),
      ],
    );
  }
}
