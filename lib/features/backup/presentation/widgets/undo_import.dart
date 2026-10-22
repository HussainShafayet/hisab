import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';

/// Asks whether to take back the import [batchId], and does it when the answer
/// is yes. Says what happened in a message. Returns true when it was undone.
Future<bool> undoImportAfterAsking(
  BuildContext context,
  WidgetRef ref,
  int batchId,
) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Undo this import?')),
      content: Text(
        tr(
          'The transactions it added will be removed. Categories and '
          'accounts it made, that nothing else uses, are hidden.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('confirm-undo'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('Undo import')),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final undone = await ref.read(csvImportRepositoryProvider).undo(batchId);
    messenger.showMessage(
      tr('Import undone: {transactions} removed.', {
        'transactions': plural(
          undone.transactions,
          '1 transaction',
          '{n} transactions',
        ),
      }),
    );
    return true;
  } on Object catch (error) {
    messenger.showError(describeError(error));
    return false;
  }
}
