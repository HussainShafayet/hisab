import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';

/// Adds a loan, or edits the name, due day and note of the one with [debtId].
class DebtFormScreen extends ConsumerWidget {
  const DebtFormScreen({this.debtId, super.key});

  final int? debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = debtId;
    if (id == null) return const _DebtForm();
    return ref
        .watch(debtProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(tr('Edit loan'))),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(tr('Edit loan'))),
            body: ErrorView(message: '$error'),
          ),
          data: (item) => item == null
              ? Scaffold(
                  appBar: AppBar(title: Text(tr('Edit loan'))),
                  body: ErrorView(message: tr('This loan no longer exists.')),
                )
              : _DebtForm(initial: item.debt),
        );
  }
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({this.initial});

  final Debt? initial;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  final _formKey = GlobalKey<FormState>();
  late final _person = TextEditingController(text: widget.initial?.person);
  late final _amount = TextEditingController();
  late final _note = TextEditingController(text: widget.initial?.note);
  DebtDirection _direction = DebtDirection.lent;
  late DateTime _openedOn = dateOnly(ref.read(clockProvider)());
  late DateTime? _dueOn = widget.initial?.dueOn;
  int? _accountId;
  List<String> _people = const [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    ref.read(debtsRepositoryProvider).knownPeople().then((people) {
      if (mounted) setState(() => _people = people);
    });
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDay(DateTime initial, {DateTime? first}) {
    final today = dateOnly(ref.read(clockProvider)());
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime(today.year + 20),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(debtsRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateDebt(
          widget.initial!.id,
          person: _person.text,
          dueOn: _dueOn,
          note: _note.text,
        );
      } else {
        await repository.createDebt(
          person: _person.text,
          direction: _direction,
          amount: parseTakaToPoisha(_amount.text)!,
          openedOn: combineDayWithTime(_openedOn, ref.read(clockProvider)()),
          dueOn: _dueOn,
          note: _note.text,
          accountId: _accountId,
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
    final typed = _person.text.trim().toLowerCase();
    final suggestions = [
      for (final name in _people)
        if (name.toLowerCase() != typed) name,
    ].take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Edit loan') : tr('New loan')),
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
                  if (!_isEditing) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('direction-lent'),
                          showCheckmark: false,
                          avatar: const Icon(Icons.call_made, size: 18),
                          label: Text(tr('I lent')),
                          selected: _direction == DebtDirection.lent,
                          onSelected: (_) =>
                              setState(() => _direction = DebtDirection.lent),
                        ),
                        ChoiceChip(
                          key: const ValueKey('direction-borrowed'),
                          showCheckmark: false,
                          avatar: const Icon(Icons.call_received, size: 18),
                          label: Text(tr('I borrowed')),
                          selected: _direction == DebtDirection.borrowed,
                          onSelected: (_) => setState(
                            () => _direction = DebtDirection.borrowed,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      child: Text(
                        _direction == DebtDirection.lent
                            ? tr(
                                'I gave money, and the other person will pay it back.',
                              )
                            : tr('I took money, and I will pay it back.'),
                        key: const ValueKey('direction-hint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: _person,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        DebtsRepository.maxPersonLength,
                      ),
                    ],
                    decoration: InputDecoration(labelText: tr('Person')),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? tr('Enter a name')
                        : null,
                  ),
                  if (suggestions.isNotEmpty && !_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final name in suggestions)
                            ActionChip(
                              key: ValueKey('person-$name'),
                              label: Text(name),
                              onPressed: () => setState(() {
                                _person.value = TextEditingValue(
                                  text: name,
                                  selection: TextSelection.collapsed(
                                    offset: name.length,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 16),
                    MoneyFormField(controller: _amount, label: tr('Amount')),
                    const SizedBox(height: 16),
                    DayField(
                      label: tr('Given on'),
                      value: _openedOn,
                      onPick: () async {
                        final day = await _pickDay(_openedOn);
                        if (day != null && mounted) {
                          setState(() => _openedOn = dateOnly(day));
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  DayField(
                    label: tr('Pay back by (optional)'),
                    value: _dueOn,
                    onPick: () async {
                      final day = await _pickDay(_dueOn ?? _openedOn);
                      if (day != null && mounted) {
                        setState(() => _dueOn = dateOnly(day));
                      }
                    },
                    onClear: () => setState(() => _dueOn = null),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: tr('Note')),
                  ),
                  if (!_isEditing && accounts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      key: const ValueKey('loan-account'),
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('Also change the balance of'),
                        helperText: tr(
                          'The money moves in this account. It is not counted as income or expense.',
                        ),
                        helperMaxLines: 3,
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(tr('No account, just a note')),
                        ),
                        for (final item in accounts)
                          DropdownMenuItem<int?>(
                            value: item.account.id,
                            child: Text(item.account.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                  child: Text(_isEditing ? tr('Save changes') : tr('Add loan')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
