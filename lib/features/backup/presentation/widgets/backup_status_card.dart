import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/time_picking.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/drive_backup_service.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';
import 'package:hishab/features/backup/presentation/drive_texts.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// At the top of Backup & export: whether the data is backed up, where, and
/// when it last was, so the person never has to wonder. Google Drive can be
/// turned on, run now, and looked at ("is the file really there?").
class BackupStatusCard extends ConsumerStatefulWidget {
  const BackupStatusCard({super.key});

  @override
  ConsumerState<BackupStatusCard> createState() => _BackupStatusCardState();
}

class _BackupStatusCardState extends ConsumerState<BackupStatusCard> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOn() => _guard(() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(driveBackupServiceProvider)
          .turnOn(ref.read(clockProvider)());
    } on DriveException catch (error) {
      final text = driveProblemText(error.problem, error.detail);
      if (text != null) messenger.showError(text);
    }
  });

  Future<void> _backUpNow() => _guard(() async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(appDatabaseProvider);
    final result = await ref
        .read(driveBackupServiceProvider)
        .attempt(ref.read(clockProvider)());
    switch (result) {
      case DriveRunResult.saved:
        messenger.showMessage(tr('Saved to Google Drive.'));
      case DriveRunResult.nothingToSave:
        messenger.showMessage(
          tr('Nothing to back up yet. Add an entry first.'),
        );
      case DriveRunResult.off:
        break;
      case DriveRunResult.failed:
        final status = DriveBackupStatus.fromSettings(
          await db.settingsDao.getAll(),
        );
        final problem = status.problem;
        final text = problem == null
            ? null
            : driveProblemText(problem, status.detail);
        messenger.showError(text ?? tr('Google Drive did not take the file.'));
    }
  });

  Future<void> _check() => _guard(() async {
    final messenger = ScaffoldMessenger.of(context);
    final DriveCheck found;
    try {
      found = await ref.read(driveBackupServiceProvider).check();
    } on DriveException catch (error) {
      final text = driveProblemText(error.problem, error.detail);
      if (text != null) messenger.showError(text);
      return;
    } on Object catch (error) {
      messenger.showError(
        error is ValidationException || error is FormatException
            ? tr('The file in Google Drive is not a Hishab backup.')
            : describeError(error),
      );
      return;
    }
    final phone = await ref
        .read(appDatabaseProvider)
        .entryCount(DateTime(2000), DateTime(2100));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CheckDialog(
        found: found,
        phoneEntries: phone,
        now: ref.read(clockProvider)(),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final now = ref.watch(clockProvider)();
    final drive = ref.watch(driveBackupStatusProvider).value;
    final auto = ref.watch(autoBackupStatusProvider).value;

    Widget row({
      required Key key,
      required IconData icon,
      required Color color,
      required String title,
      required String text,
      bool problem = false,
      List<Widget> actions = const [],
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      key: key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: problem
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: Wrap(spacing: 8, runSpacing: 4, children: actions),
            ),
        ],
      ),
    );

    String when(DateTime at) =>
        '${formatDayAndTime(at, now)} (${agoText(at, now)})';

    // Google Drive.
    final enabled = drive?.enabled ?? false;
    final problem = drive?.problem;
    final saved = drive?.lastSaved;
    final Widget driveRow;
    if (!enabled) {
      driveRow = row(
        key: const ValueKey('status-drive'),
        icon: Icons.cloud_off_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        title: tr('Google Drive'),
        text: tr(
          'Not on. Your data is only on this phone: if it is lost, so is '
          'your data.',
        ),
        actions: [
          FilledButton.tonalIcon(
            key: const ValueKey('status-drive-on'),
            onPressed: _busy ? null : _turnOn,
            icon: const Icon(Icons.add_to_drive_outlined),
            label: Text(tr('Turn on')),
          ),
        ],
      );
    } else {
      final text = problem != null
          ? (driveProblemText(problem, drive?.detail) ??
                tr('Google Drive did not take the file.'))
          : saved != null
          ? tr('Saved {when}', {'when': when(saved)})
          : tr('Not saved yet. Tap Back up now.');
      driveRow = row(
        key: const ValueKey('status-drive'),
        icon: problem != null
            ? Icons.error_outline
            : saved != null
            ? Icons.cloud_done_outlined
            : Icons.cloud_queue_outlined,
        color: problem != null
            ? theme.colorScheme.error
            : saved != null
            ? colors.income
            : theme.colorScheme.onSurfaceVariant,
        title: drive?.email == null
            ? tr('Google Drive')
            : tr('Google Drive · {email}', {'email': drive!.email}),
        text: problem != null && saved != null
            ? '$text\n${tr('Last saved {when}', {'when': when(saved)})}'
            : text,
        problem: problem != null,
        actions: [
          FilledButton.tonalIcon(
            key: const ValueKey('status-drive-now'),
            onPressed: _busy ? null : _backUpNow,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(tr('Back up now')),
          ),
          OutlinedButton.icon(
            key: const ValueKey('status-drive-check'),
            onPressed: _busy ? null : _check,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(tr('Check Drive')),
          ),
        ],
      );
    }

    // The automatic copy on this phone.
    final autoProblem = auto?.problem;
    final autoSaved = auto?.lastSaved;
    final autoRow = row(
      key: const ValueKey('status-auto'),
      icon: autoProblem != null
          ? Icons.error_outline
          : autoSaved != null
          ? Icons.phone_android
          : Icons.schedule,
      color: autoProblem != null
          ? theme.colorScheme.error
          : autoSaved != null
          ? colors.income
          : theme.colorScheme.onSurfaceVariant,
      title: tr('Copy on this phone'),
      text: autoProblem != null
          ? tr('Could not save: {reason}', {
              'reason': switch (autoProblem) {
                AutoBackupProblem.oldAndroid => tr(
                  'Needs Android 10 or newer.',
                ),
                AutoBackupProblem.failed => tr(
                  'The phone did not let the file be saved.',
                ),
              },
            })
          : autoSaved != null
          ? tr('Saved {when}', {'when': when(autoSaved)})
          : tr('Not saved yet. It saves when you leave the app.'),
      problem: autoProblem != null,
    );

    final log = drive?.log ?? const <DriveLogEntry>[];

    return Card(
      key: const ValueKey('backup-status-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Is my data backed up?'),
              style: theme.textTheme.titleMedium,
            ),
            driveRow,
            const Divider(height: 1),
            autoRow,
            if (log.isNotEmpty) ...[
              const Divider(height: 1),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('status-log'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    tr('Recent tries of Google Drive'),
                    style: theme.textTheme.titleSmall,
                  ),
                  children: [
                    for (final entry in log)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          entry.ok ? Icons.check_circle : Icons.error_outline,
                          size: 20,
                          color: entry.ok
                              ? colors.income
                              : theme.colorScheme.error,
                        ),
                        title: Text(formatDayAndTime(entry.at, now)),
                        subtitle: Text(
                          entry.ok
                              ? tr('Saved')
                              : (driveProblemText(
                                      DriveProblem.values
                                              .where(
                                                (p) => p.name == entry.problem,
                                              )
                                              .firstOrNull ??
                                          DriveProblem.failed,
                                    ) ??
                                    tr('Google Drive did not take the file.')),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckDialog extends StatelessWidget {
  const _CheckDialog({
    required this.found,
    required this.phoneEntries,
    required this.now,
  });

  final DriveCheck found;
  final int phoneEntries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title;
    final List<String> lines;
    if (!found.found) {
      title = tr('No backup in Google Drive');
      lines = [tr('Nothing is saved there yet. Tap Back up now.')];
    } else {
      title = tr('Your backup is in Google Drive');
      final modified = found.modified;
      final kb = (found.bytes / 1024).ceil();
      lines = [
        if (modified != null)
          tr('Saved {when}', {
            'when':
                '${formatDayAndTime(modified.toLocal(), now)} '
                '(${agoText(modified.toLocal(), now)})',
          }),
        tr('{size} KB: {transactions}, {accounts}, {categories}.', {
          'size': kb,
          'transactions': plural(
            found.transactions,
            '1 transaction',
            '{n} transactions',
          ),
          'accounts': plural(found.accounts, '1 account', '{n} accounts'),
          'categories': plural(
            found.categories,
            '1 category',
            '{n} categories',
          ),
        }),
        found.transactions == phoneEntries
            ? tr('Same number of transactions as on this phone.')
            : found.transactions < phoneEntries
            ? tr('This phone has {n} newer. Tap Back up now to copy them.', {
                'n': phoneEntries - found.transactions,
              })
            : tr(
                'Drive has {n} more than this phone, for example from before '
                'a reset.',
                {'n': found.transactions - phoneEntries},
              ),
      ];
    }
    return AlertDialog(
      key: const ValueKey('drive-check-dialog'),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Close')),
        ),
      ],
    );
  }
}
