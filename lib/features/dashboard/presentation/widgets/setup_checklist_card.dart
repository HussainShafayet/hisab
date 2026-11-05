import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/dashboard/domain/setup_steps.dart';
import 'package:hishab/features/dashboard/presentation/providers/home_layout_providers.dart';

String _label(SetupStep step) => switch (step) {
  SetupStep.firstEntry => tr('Write your first entry'),
  SetupStep.budget => tr('Set a budget for this month'),
  SetupStep.backup => tr('Make your first backup'),
  SetupStep.drive => tr('Turn on the Google Drive backup'),
};

/// "Get started" on Home: the first things worth doing, each one tap away. It
/// leaves once they are done, or when it is put away.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  void _open(BuildContext context, SetupStep step) {
    switch (step) {
      case SetupStep.firstEntry:
        context.push(AppRoutes.addTransaction);
      case SetupStep.budget:
        context.go(AppRoutes.budget);
      case SetupStep.backup:
      case SetupStep.drive:
        context.push(AppRoutes.backup);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(setupDismissedProvider).value ?? true;
    final progress = ref.watch(setupProgressProvider).value;
    if (dismissed || progress == null || progress.isComplete) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colors = context.financeColors;
    return Card(
      key: const ValueKey('setup-checklist'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Get started: {done} of {total}', {
                      'done': progress.doneCount,
                      'total': progress.total,
                    }),
                    key: const ValueKey('setup-count'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('setup-dismiss'),
                  tooltip: tr('Put away'),
                  icon: const Icon(Icons.close),
                  onPressed: () => ref
                      .read(appDatabaseProvider)
                      .settingsDao
                      .put(setupDismissedKey, 'true'),
                ),
              ],
            ),
            for (final step in SetupStep.values)
              ListTile(
                key: ValueKey('setup-${step.name}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  progress.done.contains(step)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: progress.done.contains(step)
                      ? colors.income
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(_label(step)),
                trailing: progress.done.contains(step)
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: progress.done.contains(step)
                    ? null
                    : () => _open(context, step),
              ),
          ],
        ),
      ),
    );
  }
}
