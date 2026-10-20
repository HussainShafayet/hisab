import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';

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
    return Card(
      key: const ValueKey('backup-reminder-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup_outlined,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Time to back up'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              days == null
                  ? tr(
                      'You have not made a backup yet. Your data lives only '
                      'on this phone.',
                    )
                  : tr(
                      'Your last backup was {n} days ago. Your data lives '
                      'only on this phone.',
                      {'n': days},
                    ),
              key: const ValueKey('backup-reminder-text'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 8,
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
                    onPressed: () => context.push(AppRoutes.backup),
                    child: Text(tr('Back up now')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
