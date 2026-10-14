import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';

/// Asks for the money put in, the profit received or the money taken back,
/// and saves it. True when it was saved, null when cancelled.
Future<bool?> showInvestmentEntryDialog(
  BuildContext context, {
  required InvestmentItem item,
  required InvestmentEntryKind kind,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _EntryDialog(item: item, kind: kind),
  );
}

class _EntryDialog extends ConsumerStatefulWidget {
  const _EntryDialog({required this.item, required this.kind});

  final InvestmentItem item;
  final InvestmentEntryKind kind;

  @override
  ConsumerState<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<_EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day = dateOnly(ref.read(clockProvider)());
  int? _accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    InvestmentEntryKind.putIn => tr('Put money in'),
    InvestmentEntryKind.profit => tr('Got profit'),
    InvestmentEntryKind.takeBack => tr('Took money back'),
  };

  String get _hint => switch (widget.kind) {
    InvestmentEntryKind.putIn => tr(
      'Money you put into it. It is not counted as spending.',
    ),
    InvestmentEntryKind.profit => tr(
      'Profit you received. It counts as income.',
    ),
    InvestmentEntryKind.takeBack => tr(
      'Part of the money you put in, taken back. It is not income.',
    ),
  };

  Future<void> _pickDay() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTakaToPoisha(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('The amount must be above zero.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(investmentsRepositoryProvider)
          .addEntry(
            widget.item.investment.id,
            kind: widget.kind,
            amount: amount,
            date: combineDayWithTime(_day, ref.read(clockProvider)()),
            note: _note.text,
            accountId: _accountId,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
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

    return AlertDialog(
      title: Text(_title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              MoneyFormField(
                key: const ValueKey('investment-amount'),
                controller: _amount,
                label: tr('Amount'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: const ValueKey('investment-account'),
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Account (optional)'),
                  helperText: widget.kind == InvestmentEntryKind.putIn
                      ? tr('The money leaves this account.')
                      : tr('The money arrives in this account.'),
                  helperMaxLines: 2,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(tr('Only record it')),
                  ),
                  for (final item in accounts)
                    DropdownMenuItem<int?>(
                      value: item.account.id,
                      child: Text(item.account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('investment-note'),
                controller: _note,
                maxLength: InvestmentsRepository.maxNoteLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Note (optional)')),
              ),
              const SizedBox(height: 4),
              DayField(label: tr('Date'), value: _day, onPick: _pickDay),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('investment-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('investment-save'),
          onPressed: _saving ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}

/// Asks what the money still in the investment is worth now, and saves it.
/// True when it was saved, null when cancelled.
Future<bool?> showInvestmentValueDialog(
  BuildContext context, {
  required InvestmentItem item,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ValueDialog(item: item),
  );
}

class _ValueDialog extends ConsumerStatefulWidget {
  const _ValueDialog({required this.item});

  final InvestmentItem item;

  @override
  ConsumerState<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends ConsumerState<_ValueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _value = TextEditingController(
    text: widget.item.investment.currentValue == null
        ? ''
        : poishaToInput(widget.item.investment.currentValue!),
  );
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save(int? value) async {
    try {
      await ref
          .read(investmentsRepositoryProvider)
          .setCurrentValue(widget.item.investment.id, value);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(tr('What is it worth now?')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  'What the money still in it would be worth if you took it '
                  'out today. Without a value, it counts as what it cost: '
                  '{amount}.',
                  {'amount': formatPoisha(widget.item.stillIn)},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              MoneyFormField(
                key: const ValueKey('investment-value'),
                controller: _value,
                label: tr('Worth now'),
                autofocus: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('investment-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        if (widget.item.investment.currentValue != null)
          TextButton(
            key: const ValueKey('investment-value-clear'),
            onPressed: () => _save(null),
            child: Text(tr('Back to cost')),
          ),
        FilledButton(
          key: const ValueKey('investment-value-save'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            _save(parseTakaToPoisha(_value.text));
          },
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
