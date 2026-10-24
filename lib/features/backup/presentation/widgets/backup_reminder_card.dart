import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// On Home: asks for a backup when it has been two weeks, or none was ever
/// made. Not shown otherwise, or when the reminder is off (Settings > Data).
class BackupReminderCard extends ConsumerWidget {
  const BackupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(backupDueProvider);
    if (due == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final days = due.daysSince;
    // With the automatic backup on, a copy is on the phone already: what is
    // asked for is one that survives the phone, sent with one tap.
    final sendAway = ref.watch(preferencesProvider.select((p) => p.autoBackup));
    return Card(
      key: const ValueKey('backup-reminder-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.backup_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Time to back up'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sendAway
                            ? (days == null
                                  ? tr(
                                      'A copy is saved on this phone, but it '
                                      'is lost with the phone. Send one to '
                                      'Drive or email.',
                                    )
                                  : tr(
                                      'The last copy you sent away was {n} '
                                      'days ago. The one on this phone is lost '
                                      'with the phone, so send a new one to '
                                      'Drive or email.',
                                      {'n': days},
                                    ))
                            : days == null
                            ? tr(
                                'You have not made a backup yet. Your data '
                                'lives only on this phone.',
                              )
                            : tr(
                                'Your last backup was {n} days ago. Your '
                                'data lives only on this phone.',
                                {'n': days},
                              ),
                        key: const ValueKey('backup-reminder-text'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('backup-later'),
                    onPressed: () => ref
                        .read(backupRepositoryProvider)
                        .snoozeReminder(ref.read(clockProvider)()),
                    child: Text(tr('Later')),
                  ),
                  FilledButton(
                    key: const ValueKey('backup-now'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: sendAway
                        ? () => _sendCopy(context, ref)
                        : () => context.push(AppRoutes.backup),
                    child: Text(
                      sendAway ? tr('Send a copy') : tr('Back up now'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the share sheet with the backup file ready, so one tap and a choice
  /// of Drive, email or a chat sends a copy away. Then Home stops asking.
  Future<void> _sendCopy(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(backupRepositoryProvider);
    final now = ref.read(clockProvider)();
    try {
      final backup = await repository.buildBackup(now);
      await ref
          .read(fileGatewayProvider)
          .share(
            fileName:
                'hishab-backup-${DateFormat('yyyy-MM-dd', 'en').format(now)}'
                '.json',
            bytes: Uint8List.fromList(utf8.encode(backup.encode())),
            mimeType: 'application/json',
          );
      await repository.markBackedUp(now);
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }
}
