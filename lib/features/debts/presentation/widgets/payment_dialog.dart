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
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';

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
  late DateTime _day = dateOnly(ref.read(clockProvider)());
  late int? _accountId = widget.item.debt.accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(debtsRepositoryProvider)
          .addPayment(
            widget.item.debt.id,
            amount: parseTakaToPoisha(_amount.text)!,
            paidOn: combineDayWithTime(_day, ref.read(clockProvider)()),
            note: _note.text,
            accountId: _accountId,
          );
      if (mounted) Navigator.of(context).pop(true);
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
    final accounts =
        ref.watch(accountsProvider(false)).value ??
        const <AccountWithBalance>[];
    final lent = widget.item.debt.direction == DebtDirection.lent;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(lent ? tr('Money received') : tr('Money paid back')),
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
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: const ValueKey('payment-account'),
                  initialValue: accounts.any((a) => a.account.id == _accountId)
                      ? _accountId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('Also change the balance of'),
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
