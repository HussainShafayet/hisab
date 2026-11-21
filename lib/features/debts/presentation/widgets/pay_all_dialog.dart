import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_account_field.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// What "All paid" does about the money: it moves [accountId], or no account
/// when that is null, and [fee] is a transfer charge taken on top (poisha).
typedef PayAllChoice = ({int? accountId, int fee});

/// Says that the rest of a loan is paid today, and asks which account the
/// money comes out of or goes into (or none). Pops with the choice, or with
/// null when cancelled.
class PayAllDialog extends ConsumerStatefulWidget {
  const PayAllDialog({required this.item, super.key});

  final DebtItem item;

  @override
  ConsumerState<PayAllDialog> createState() => _PayAllDialogState();
}

class _PayAllDialogState extends ConsumerState<PayAllDialog> {
  late int? _accountId = widget.item.debt.accountId;
  final _fee = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(accountsProvider(true)).value ?? const <AccountWithBalance>[];
    // An archived account cannot be used for a new payment.
    final accounts = [
      for (final a in all)
        if (!a.account.isArchived) a,
    ];
    final chosen = accounts.any((a) => a.account.id == _accountId)
        ? _accountId
        : null;
    final lent = widget.item.debt.direction == DebtDirection.lent;
    final fee = lent || chosen == null
        ? 0
        : (parseTakaToPoisha(_fee.text) ?? 0);

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
                tr('This pays the {amount} that is left.', {
                  'amount': formatPoisha(widget.item.remaining),
                }),
                key: const ValueKey('pay-all-note'),
              ),
              const SizedBox(height: 8),
              LoanAccountField(
                switchKey: const ValueKey('pay-all-account-switch'),
                accounts: accounts,
                accountId: chosen,
                moneyIn: lent,
                amount: widget.item.remaining + fee,
                preferredId:
                    widget.item.debt.accountId ??
                    ref.read(preferencesProvider).defaultAccountId,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              if (!lent && chosen != null) ...[
                const SizedBox(height: 8),
                MoneyFormField(
                  key: const ValueKey('pay-all-fee'),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('pay-all-confirm'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? true)) return;
            Navigator.of(context).pop((accountId: chosen, fee: fee));
          },
          child: Text(tr('All paid')),
        ),
      ],
    );
  }
}
