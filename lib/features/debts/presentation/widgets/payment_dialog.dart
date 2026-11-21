import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/features/fun/presentation/celebrate.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_account_field.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// Asks how much was paid back, and when, and records it. Pops with true when
/// it was recorded.
class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({required this.item, super.key});

  final DebtItem item;

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: poishaToInput(widget.item.remaining),
  );
  final _note = TextEditingController();
  final _fee = TextEditingController();
  late DateTime _day = dateOnly(ref.read(clockProvider)());
  late int? _accountId = widget.item.debt.accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final amount = parseTakaToPoisha(_amount.text)!;
      await ref
          .read(debtsRepositoryProvider)
          .addPayment(
            widget.item.debt.id,
            amount: amount,
            paidOn: combineDayWithTime(_day, ref.read(clockProvider)()),
            note: _note.text,
            accountId: _accountId,
            // A transfer charge only comes with an account, on a loan I took.
            fee:
                _accountId == null ||
                    widget.item.debt.direction == DebtDirection.lent
                ? 0
                : parseTakaToPoisha(_fee.text) ?? 0,
          );
      // The payment that clears the loan: a little celebration.
      if (mounted && amount >= widget.item.remaining) celebrate(context, ref);
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
    final all =
        ref.watch(accountsProvider(true)).value ?? const <AccountWithBalance>[];
    // Archived accounts cannot be chosen, except the one the loan uses.
    final accounts = [
      for (final a in all)
        if (!a.account.isArchived || a.account.id == widget.item.debt.accountId)
          a,
    ];
    final lent = widget.item.debt.direction == DebtDirection.lent;
    final theme = Theme.of(context);
    final chosenAccount = accounts.any((a) => a.account.id == _accountId)
        ? _accountId
        : null;
    // What leaves the account: the payment and, for a loan I took, its charge.
    final paying = parseTakaToPoisha(_amount.text);
    final fee = lent ? 0 : (parseTakaToPoisha(_fee.text) ?? 0);

    return AlertDialog(
      title: Text(lent ? tr('They paid me') : tr('I paid them')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('{amount} is left.', {
                  'amount': formatPoisha(widget.item.remaining),
                }),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              MoneyFormField(
                controller: _amount,
                label: tr('Amount'),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
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
                controller: _note,
                decoration: InputDecoration(labelText: tr('Note')),
              ),
              const SizedBox(height: 4),
              LoanAccountField(
                switchKey: const ValueKey('payment-account-switch'),
                accounts: accounts,
                accountId: accounts.any((a) => a.account.id == _accountId)
                    ? _accountId
                    : null,
                moneyIn: lent,
                amount: paying == null ? null : paying + fee,
                preferredId:
                    widget.item.debt.accountId ??
                    ref.read(preferencesProvider).defaultAccountId,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              if (!lent && chosenAccount != null) ...[
                const SizedBox(height: 8),
                MoneyFormField(
                  key: const ValueKey('payment-fee'),
                  controller: _fee,
                  label: tr('Transfer charge'),
                  isRequired: false,
                  helperText: tr(
                    'Taken by the bank or bKash when you send. It is an '
                    'expense on this account.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const ValueKey('payment-error'),
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
          onPressed: _saving ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
