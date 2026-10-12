import 'package:flutter/material.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';

/// Lets the user choose one of [accounts] from a sheet of wallet cards, and
/// returns its id (null when the sheet is dismissed). [balances] maps an
/// account id to its balance in poisha. The card of [disabledId] is shown but
/// cannot be chosen, for the other end of a transfer.
Future<int?> showAccountPicker(
  BuildContext context, {
  required String title,
  required List<Account> accounts,
  required Map<int, int> balances,
  int? selectedId,
  int? disabledId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final account in accounts)
                    Padding(
                      key: ValueKey('account-option-${account.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: account.id == disabledId ? 0.4 : 1,
                        child: AccountCard(
                          account: account,
                          balance: balances[account.id],
                          selected: account.id == selectedId,
                          onTap: account.id == disabledId
                              ? null
                              : () => Navigator.of(context).pop(account.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
