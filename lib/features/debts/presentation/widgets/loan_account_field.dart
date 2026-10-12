import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_picker_sheet.dart';

/// "Update my account too": a switch that, when on, shows the account as a
/// wallet card with its balance now and after this money moves.
///
/// [moneyIn] is true when the money goes into the account. [amount] is what is
/// being recorded, for the "After this" line. When a loan that already moved
/// an account is edited, [alreadyApplied] says how it moved the balance, so
/// the balance shown does not count it twice.
class LoanAccountField extends StatelessWidget {
  const LoanAccountField({
    required this.accounts,
    required this.accountId,
    required this.onChanged,
    required this.moneyIn,
    required this.amount,
    this.preferredId,
    this.alreadyApplied,
    this.switchKey = const ValueKey('loan-account-switch'),
    super.key,
  });

  /// The accounts that can be used (not archived), with their balances.
  final List<AccountWithBalance> accounts;

  /// The account that is chosen, or null when the switch is off.
  final int? accountId;
  final ValueChanged<int?> onChanged;
  final bool moneyIn;

  /// In poisha; null while nothing valid is typed.
  final int? amount;

  /// The account to pick when the switch is turned on (the default account).
  final int? preferredId;
  final ({int accountId, int change})? alreadyApplied;
  final Key switchKey;

  AccountWithBalance? get _chosen =>
      accounts.where((a) => a.account.id == accountId).firstOrNull;

  Future<void> _pick(BuildContext context) async {
    final id = await showAccountPicker(
      context,
      title: tr('Choose an account'),
      accounts: [for (final a in accounts) a.account],
      balances: {for (final a in accounts) a.account.id: a.balance},
      selectedId: accountId,
    );
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final chosen = _chosen;

    int? after;
    if (chosen != null && amount != null && amount! > 0) {
      final undo = alreadyApplied?.accountId == chosen.account.id
          ? alreadyApplied!.change
          : 0;
      after = chosen.balance - undo + (moneyIn ? amount! : -amount!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: switchKey,
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Update my account too')),
          subtitle: Text(
            moneyIn
                ? tr(
                    'The money is added to the account. It does not count '
                    'as income.',
                  )
                : tr(
                    'The money is taken from the account. It does not count '
                    'as spending.',
                  ),
            style: theme.textTheme.bodySmall,
          ),
          value: chosen != null,
          onChanged: (on) {
            if (!on) return onChanged(null);
            final preferred = accounts.any((a) => a.account.id == preferredId)
                ? preferredId
                : accounts.first.account.id;
            onChanged(preferred);
          },
        ),
        if (chosen != null) ...[
          const SizedBox(height: 4),
          AccountCard(
            key: ValueKey('loan-account-${chosen.account.id}'),
            account: chosen.account,
            balance: chosen.balance,
            balanceAfter: after,
            caption: moneyIn ? tr('Goes into') : tr('Comes out of'),
            trailing: const Icon(Icons.expand_more, color: Colors.white),
            onTap: () => _pick(context),
          ),
        ],
      ],
    );
  }
}
