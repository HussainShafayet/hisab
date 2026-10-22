import 'package:flutter/material.dart';
import 'package:hishab/features/accounts/domain/account.dart';

/// A sheet with the accounts to choose one from. Returns the id of the one
/// chosen, or null when it is dismissed.
Future<int?> showAccountChoice(
  BuildContext context, {
  required String title,
  required List<Account> accounts,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final account in accounts)
                  ListTile(
                    key: ValueKey('choose-account-${account.id}'),
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(account.name),
                    onTap: () => Navigator.of(context).pop(account.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
