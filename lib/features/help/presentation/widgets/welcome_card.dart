import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';

/// The key under which "the welcome card was put away" is saved.
const welcomeDismissedKey = 'welcome_dismissed';

/// True once the welcome card was dismissed (or its tour taken).
final welcomeDismissedProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchAll()
      .map((saved) => saved[welcomeDismissedKey] == 'true'),
);

/// True while nothing has been written yet: the person is new.
final hasNoEntriesProvider = FutureProvider<bool>((ref) async {
  ref.watch(dataChangesProvider);
  final db = ref.read(appDatabaseProvider);
  return await db.entryCount(DateTime(2000), DateTime(2200)) == 0;
});

/// A friendly hello at the top of Home for someone who has not written
/// anything yet, with the one-minute tour (the guide's Start here).
class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key});

  Future<void> _put(WidgetRef ref) => ref
      .read(appDatabaseProvider)
      .settingsDao
      .put(welcomeDismissedKey, 'true');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(welcomeDismissedProvider).value ?? true;
    final isNew = ref.watch(hasNoEntriesProvider).value ?? false;
    if (dismissed || !isNew) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const ValueKey('welcome-card'),
      color: colors.primaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waving_hand_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Welcome to Hishab'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'New here? A one-minute tour shows how to set things up and '
                'write your first entry.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('welcome-dismiss'),
                  onPressed: () => _put(ref),
                  child: Text(tr('Not now')),
                ),
                FilledButton(
                  key: const ValueKey('welcome-tour'),
                  onPressed: () {
                    _put(ref);
                    context.push(AppRoutes.helpTopic('start'));
                  },
                  child: Text(tr('Take the tour')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
