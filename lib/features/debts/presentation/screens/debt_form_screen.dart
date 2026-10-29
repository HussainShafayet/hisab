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
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_account_field.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/core/widgets/discard_guard.dart';

/// Adds a loan, or edits the one with [debtId]. [initialPerson] fills in the
/// name of a new loan, and [initialDirection] says which way it starts (the tab
/// of the list the add button was on).
class DebtFormScreen extends ConsumerWidget {
  const DebtFormScreen({
    this.debtId,
    this.initialPerson,
    this.initialDirection,
    super.key,
  });

  final int? debtId;
  final String? initialPerson;
  final DebtDirection? initialDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = debtId;
    if (id == null) {
      return _DebtForm(
        initialPerson: initialPerson,
        initialDirection: initialDirection,
      );
    }
    return ref
        .watch(debtProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(tr('Edit loan'))),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(tr('Edit loan'))),
            body: ErrorView(message: describeError(error)),
          ),
          data: (item) => item == null
              ? Scaffold(
                  appBar: AppBar(title: Text(tr('Edit loan'))),
                  body: ErrorView(message: tr('This loan no longer exists.')),
                )
              : _DebtForm(initial: item.debt, paid: item.paid),
        );
  }
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({
    this.initial,
    this.paid = 0,
    this.initialPerson,
    this.initialDirection,
  });

  final Debt? initial;

  /// How much of the loan is paid already (editing only).
  final int paid;
  final String? initialPerson;
  final DebtDirection? initialDirection;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  final _formKey = GlobalKey<FormState>();
  late final _person = TextEditingController(
    text: widget.initial?.person ?? widget.initialPerson,
  );
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : poishaToInput(widget.initial!.amount),
  );
  late final _note = TextEditingController(text: widget.initial?.note);
  late DebtDirection _direction =
      widget.initial?.direction ??
      widget.initialDirection ??
      DebtDirection.lent;
  late DateTime _openedOn = dateOnly(
    widget.initial?.openedOn ?? ref.read(clockProvider)(),
  );
  late DateTime? _dueOn = widget.initial?.dueOn;
  late int? _accountId = widget.initial?.accountId;
  List<String> _people = const [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  /// The kind of loan is fixed once a payment was made: it went one way.
  bool get _kindLocked => _isEditing && widget.paid > 0;

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

  Future<DateTime?> _pickDay(DateTime initial) {
    final today = dateOnly(ref.read(clockProvider)());
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
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
    final now = ref.read(clockProvider)();
    final initial = widget.initial;
    try {
      if (initial != null) {
        await repository.updateDebt(
          initial.id,
          person: _person.text,
          direction: _direction,
          amount: parseTakaToPoisha(_amount.text)!,
          // The time of day stays when the day was not changed.
          openedOn: _openedOn == dateOnly(initial.openedOn)
              ? initial.openedOn
              : combineDayWithTime(_openedOn, now),
          dueOn: _dueOn,
          note: _note.text,
          accountId: _accountId,
        );
      } else {
        await repository.createDebt(
          person: _person.text,
          direction: _direction,
          amount: parseTakaToPoisha(_amount.text)!,
          openedOn: combineDayWithTime(_openedOn, now),
          dueOn: _dueOn,
          note: _note.text,
          accountId: _accountId,
        );
      }
      // A due day sets a reminder, which needs the person's say-so.
      if (_dueOn != null && _dueOn != initial?.dueOn) {
        await ref.read(reminderSchedulerProvider).requestPermission();
      }
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  /// What the text fields held on opening, to tell if anything was typed.
  late final _snapshot = TextSnapshot([_person, _amount, _note]);

  @override
  Widget build(BuildContext context) =>
      DiscardGuard(snapshot: _snapshot, child: _buildForm(context));

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final all =
        ref.watch(accountsProvider(true)).value ?? const <AccountWithBalance>[];
    // Archived accounts cannot be chosen, except the one this loan uses now.
    final accounts = [
      for (final a in all)
        if (!a.account.isArchived || a.account.id == widget.initial?.accountId)
          a,
    ];
    final typed = _person.text.trim().toLowerCase();
    final suggestions = [
      for (final name in _people)
        if (name.toLowerCase() != typed) name,
    ].take(6).toList();
    final lent = _direction == DebtDirection.lent;
    final initial = widget.initial;

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
                  Row(
                    children: [
                      Expanded(
                        child: _DirectionTile(
                          key: const ValueKey('direction-lent'),
                          icon: Icons.call_made,
                          title: tr('I gave money'),
                          subtitle: tr('They will pay me back'),
                          selected: lent,
                          enabled: !_kindLocked,
                          onTap: () =>
                              setState(() => _direction = DebtDirection.lent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DirectionTile(
                          key: const ValueKey('direction-borrowed'),
                          icon: Icons.call_received,
                          title: tr('I took money'),
                          subtitle: tr('I will pay it back'),
                          selected: !lent,
                          enabled: !_kindLocked,
                          onTap: () => setState(
                            () => _direction = DebtDirection.borrowed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_kindLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        tr('This cannot change once something is paid.'),
                        key: const ValueKey('kind-locked'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _person,
                    autofocus: !_isEditing && widget.initialPerson == null,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        DebtsRepository.maxPersonLength,
                      ),
                    ],
                    decoration: InputDecoration(labelText: tr('Name')),
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
                  const SizedBox(height: 16),
                  MoneyFormField(
                    controller: _amount,
                    label: tr('Amount'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  LoanAccountField(
                    accounts: accounts,
                    accountId: _accountId,
                    moneyIn: !lent,
                    amount: parseTakaToPoisha(_amount.text),
                    preferredId: ref.read(preferencesProvider).defaultAccountId,
                    alreadyApplied: initial?.accountId == null
                        ? null
                        : (
                            accountId: initial!.accountId!,
                            change: initial.direction == DebtDirection.lent
                                ? -initial.amount
                                : initial.amount,
                          ),
                    onChanged: (id) => setState(() => _accountId = id),
                  ),
                  // Closed at first: most loans need only the three above.
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: const ValueKey('more-details'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      initiallyExpanded:
                          _isEditing &&
                          (_dueOn != null || _note.text.isNotEmpty),
                      title: Text(tr('More details')),
                      subtitle: Text(
                        tr('Date, pay back date, note'),
                        style: theme.textTheme.bodySmall,
                      ),
                      children: [
                        DayField(
                          label: tr('Date'),
                          value: _openedOn,
                          onPick: () async {
                            final day = await _pickDay(_openedOn);
                            if (day != null && mounted) {
                              setState(() => _openedOn = dateOnly(day));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DayField(
                          label: tr('Pay back date (optional)'),
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
                      ],
                    ),
                  ),
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

/// One of the two big choices: money I gave, or money I took.
class _DirectionTile extends StatelessWidget {
  const _DirectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: enabled || selected ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(height: 6),
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
