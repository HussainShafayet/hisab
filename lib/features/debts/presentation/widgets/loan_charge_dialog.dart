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
import 'package:hishab/features/accounts/presentation/widgets/account_picker_sheet.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// What a kind of charge is called.
String debtChargeKindLabel(DebtChargeKind kind) => switch (kind) {
  DebtChargeKind.lateFee => tr('Late fee'),
  DebtChargeKind.interest => tr('Interest'),
  DebtChargeKind.serviceCharge => tr('Service charge'),
  DebtChargeKind.other => tr('Other'),
};

/// Adds a late fee, interest or another charge to a loan I took: it is added
/// to what I owe and, if I want, to my spending. Pops with true when saved.
class LoanChargeDialog extends ConsumerStatefulWidget {
  const LoanChargeDialog({required this.item, super.key});

  final DebtItem item;

  @override
  ConsumerState<LoanChargeDialog> createState() => _LoanChargeDialogState();
}

class _LoanChargeDialogState extends ConsumerState<LoanChargeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day = dateOnly(ref.read(clockProvider)());
  DebtChargeKind _kind = DebtChargeKind.lateFee;
  bool _expense = true;
  int? _accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// The accounts that can be written on (not archived).
  List<AccountWithBalance> _usable() {
    final all =
        ref.read(accountsProvider(true)).value ?? const <AccountWithBalance>[];
    return [
      for (final a in all)
        if (!a.account.isArchived) a,
    ];
  }

  /// The account the expense is written on: the one chosen, else the loan's,
  /// else the default account, else the first one.
  int? _anchor(List<AccountWithBalance> usable) {
    bool ok(int? id) => id != null && usable.any((a) => a.account.id == id);
    if (ok(_accountId)) return _accountId;
    if (ok(widget.item.debt.accountId)) return widget.item.debt.accountId;
    final preferred = ref.read(preferencesProvider).defaultAccountId;
    if (ok(preferred)) return preferred;
    return usable.firstOrNull?.account.id;
  }

  Future<void> _pickAccount(List<AccountWithBalance> usable) async {
    final id = await showAccountPicker(
      context,
      title: tr('Choose an account'),
      accounts: [for (final a in usable) a.account],
      balances: {for (final a in usable) a.account.id: a.balance},
      selectedId: _anchor(usable),
    );
    if (id != null && mounted) setState(() => _accountId = id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final usable = _usable();
      await ref
          .read(debtsRepositoryProvider)
          .addCharge(
            widget.item.debt.id,
            amount: parseTakaToPoisha(_amount.text)!,
            chargedOn: combineDayWithTime(_day, ref.read(clockProvider)()),
            kind: _kind,
            note: _note.text,
            accountId: _expense ? _anchor(usable) : null,
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
    // Watched, so the list is there by the time Save is pressed.
    ref.watch(accountsProvider(true));
    final usable = _usable();
    final anchor = _anchor(usable);
    final account = usable
        .where((a) => a.account.id == anchor)
        .map((a) => a.account)
        .firstOrNull;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(tr('Add a late fee or charge')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('It is added to what you owe {name}.', {
                  'name': widget.item.debt.person,
                }),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final kind in DebtChargeKind.values)
                    ChoiceChip(
                      key: ValueKey('charge-kind-${kind.name}'),
                      label: Text(debtChargeKindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MoneyFormField(
                key: const ValueKey('charge-amount'),
                controller: _amount,
                label: tr('Amount'),
                autofocus: true,
              ),
              if (account != null) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const ValueKey('charge-expense-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Count it as my expense')),
                  subtitle: Text(
                    tr(
                      'It shows in your spending and reports. No account '
                      'balance changes.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _expense,
                  onChanged: (on) => setState(() => _expense = on),
                ),
                if (_expense)
                  ListTile(
                    key: const ValueKey('charge-account'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(tr('Written on')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(account.name),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    onTap: () => _pickAccount(usable),
                  ),
              ],
              const SizedBox(height: 12),
              DayField(
                label: tr('Date'),
                value: _day,
                onPick: () async {
                  final today = dateOnly(ref.read(clockProvider)());
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _day.isAfter(today) ? today : _day,
                    firstDate: DateTime(2000),
                    lastDate: today,
                  );
                  if (picked != null && mounted) {
                    setState(() => _day = dateOnly(picked));
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('charge-note'),
                controller: _note,
                decoration: InputDecoration(labelText: tr('Note')),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const ValueKey('charge-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('charge-save'),
          onPressed: _saving ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
