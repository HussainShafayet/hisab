import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

/// Things to do with one transaction outside the Transactions list: from an
/// account's page and from the edit form.

/// Deletes the transaction and says so; the message has an Undo that puts it
/// back. True when it was deleted.
Future<bool> deleteTransactionWithUndo(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final repository = ref.read(transactionsRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final deleted = await repository.deleteTransaction(id);
    if (deleted == null) return false;
    messenger.showMessage(
      tr('Transaction deleted'),
      duration: undoDuration,
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.restoreTransaction(deleted),
      ),
    );
    return true;
  } on Object catch (error) {
    messenger.showError(describeError(error));
    return false;
  }
}

/// A sheet with Edit, Duplicate and Delete for [item].
Future<void> showTransactionActions(
  BuildContext context,
  WidgetRef ref,
  TransactionItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('entry-action-edit'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(tr('Edit')),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRoutes.editTransaction(item.id));
            },
          ),
          ListTile(
            key: const ValueKey('entry-action-duplicate'),
            leading: const Icon(Icons.copy_outlined),
            title: Text(tr('Duplicate')),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRoutes.duplicateTransaction(item.id));
            },
          ),
          ListTile(
            key: const ValueKey('entry-action-delete'),
            leading: const Icon(Icons.delete_outline),
            title: Text(tr('Delete')),
            onTap: () {
              Navigator.of(sheetContext).pop();
              deleteTransactionWithUndo(context, ref, item.id);
            },
          ),
        ],
      ),
    ),
  );
}
