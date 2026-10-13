import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:intl/intl.dart';

enum _Delivery { save, share }

/// Backup and restore, and moving transactions in and out as a spreadsheet.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  void _message(String text) {
    ScaffoldMessenger.of(context).showMessage(text);
  }

  Future<void> _problem(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  /// Runs [action] with the progress bar showing. If it fails the bar goes
  /// away first, and then the problem is shown: the bar means "working", and
  /// nothing is working while the user reads an error.
  Future<void> _run(String failureTitle, Future<void> Function() action) async {
    setState(() => _busy = true);
    Object? failure;
    try {
      await action();
    } on Object catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) await _problem(failureTitle, describeError(failure));
  }

  /// Asks whether to save the file on the phone or share it, and does it.
  Future<void> _deliver({
    required String fileName,
    required String text,
    required String mimeType,
    required String doneMessage,
  }) async {
    final choice = await showModalBottomSheet<_Delivery>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('deliver-save'),
              leading: const Icon(Icons.download_outlined),
              title: Text(tr('Save to this phone')),
              subtitle: Text(tr('Choose a folder, for example Downloads')),
              onTap: () => Navigator.of(context).pop(_Delivery.save),
            ),
            ListTile(
              key: const ValueKey('deliver-share'),
              leading: const Icon(Icons.share_outlined),
              title: Text(tr('Share')),
              subtitle: Text(tr('Send it to Google Drive, email, ...')),
              onTap: () => Navigator.of(context).pop(_Delivery.share),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final bytes = Uint8List.fromList(utf8.encode(text));
    final gateway = ref.read(fileGatewayProvider);
    if (choice == _Delivery.save) {
      final saved = await gateway.save(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (saved && mounted) _message(doneMessage);
    } else {
      await gateway.share(fileName: fileName, bytes: bytes, mimeType: mimeType);
    }
  }

  String _today() =>
      DateFormat('yyyy-MM-dd', 'en').format(ref.read(clockProvider)());

  /// Makes the file with the progress bar showing, then (with the bar gone,
  /// because now it is the user's turn) asks where to put it.
  Future<void> _export({
    required String failureTitle,
    required Future<String> Function() makeText,
    required String fileName,
    required String mimeType,
    required String doneMessage,
  }) async {
    final String text;
    setState(() => _busy = true);
    try {
      text = await makeText();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _problem(failureTitle, describeError(error));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    try {
      await _deliver(
        fileName: fileName,
        text: text,
        mimeType: mimeType,
        doneMessage: doneMessage,
      );
    } on Object catch (error) {
      if (mounted) await _problem(failureTitle, describeError(error));
    }
  }

  Future<void> _exportBackup() => _export(
    failureTitle: tr('Could not export the backup'),
    makeText: () async =>
        (await ref
                .read(backupRepositoryProvider)
                .buildBackup(ref.read(clockProvider)()))
            .encode(),
    fileName: 'hishab-backup-${_today()}.json',
    mimeType: 'application/json',
    doneMessage: tr('Backup saved.'),
  );

  Future<void> _exportCsv() => _export(
    failureTitle: tr('Could not export the transactions'),
    makeText: () => ref.read(backupRepositoryProvider).exportTransactionsCsv(),
    fileName: 'hishab-transactions-${_today()}.csv',
    mimeType: 'text/csv',
    doneMessage: tr('Transactions saved.'),
  );

  Future<bool> _confirmRestore(BackupData data) async {
    final made = DateFormat('d MMM yyyy, HH:mm')
        .format(data.exportedAt.toLocal());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Restore this backup?')),
        content: Text(
          tr(
            'Made on {date}. It holds {accounts}, {categories}, '
            '{transactions} and {budgets}.\n\n'
            'Everything on this phone now will be replaced by it. This cannot '
            'be undone. Export a backup first if you want to keep what you '
            'have.',
            {
              'date': made,
              'accounts': plural(
                data.accounts.length,
                '1 account',
                '{n} accounts',
              ),
              'categories': plural(
                data.categories.length,
                '1 category',
                '{n} categories',
              ),
              'transactions': plural(
                data.transactions.length,
                '1 transaction',
                '{n} transactions',
              ),
              'budgets': plural(data.budgets.length, '1 budget', '{n} budgets'),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Replace everything')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _restore() async {
    final PickedFile? picked;
    try {
      picked = await ref.read(fileGatewayProvider).pick(extensions: ['json']);
    } on Object catch (error) {
      await _problem(tr('Could not open the file'), describeError(error));
      return;
    }
    if (picked == null || !mounted) return;

    final BackupData data;
    try {
      data = BackupData.decode(utf8.decode(picked.bytes));
    } on FormatException {
      await _problem(
        tr('This backup cannot be restored'),
        tr('This file is not a Hishab backup.'),
      );
      return;
    } on Object catch (e) {
      await _problem(tr('This backup cannot be restored'), describeError(e));
      return;
    }
    if (!mounted || !await _confirmRestore(data)) return;

    await _run(tr('Could not restore the backup'), () async {
      await ref.read(backupRepositoryProvider).restore(data);
      if (mounted) {
        _message(
          tr('Backup restored: {transactions}.', {
            'transactions': plural(
              data.transactions.length,
              '1 transaction',
              '{n} transactions',
            ),
          }),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Backup & export'))),
      body: Stack(
        children: [
          ListView(
            children: [
              heading(tr('Backup')),
              ListTile(
                key: const ValueKey('export-backup'),
                leading: const Icon(Icons.save_alt),
                title: Text(tr('Export backup')),
                subtitle: Text(
                  tr(
                    'Everything in one file: accounts, categories, '
                    'transactions and budgets.',
                  ),
                ),
                enabled: !_busy,
                onTap: _exportBackup,
              ),
              ListTile(
                key: const ValueKey('restore-backup'),
                leading: const Icon(Icons.restore),
                title: Text(tr('Restore from backup')),
                subtitle: Text(
                  tr('Replaces everything on this phone with a backup file.'),
                ),
                enabled: !_busy,
                onTap: _restore,
              ),
              heading(tr('Spreadsheet (CSV)')),
              ListTile(
                key: const ValueKey('export-csv'),
                leading: const Icon(Icons.table_view_outlined),
                title: Text(tr('Export transactions')),
                subtitle: Text(tr('Open them in Google Sheets or Excel.')),
                enabled: !_busy,
                onTap: _exportCsv,
              ),
              ListTile(
                key: const ValueKey('import-csv'),
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(tr('Import from CSV')),
                subtitle: Text(
                  tr(
                    'Bring in transactions from your sheet. You say which '
                    'column is which.',
                  ),
                ),
                enabled: !_busy,
                onTap: () => context.push(AppRoutes.importCsv),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr(
                    'Hishab never sends your data anywhere. Keep a backup '
                    'somewhere safe, like Google Drive, in case you lose or '
                    'change your phone.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
