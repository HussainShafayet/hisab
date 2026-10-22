import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// The part of Home that is nice to have and not needed every day: the
/// mascot, the streak, how the month felt, tips. It is closed until the
/// person opens it with one tap, and stays as they left it.
class HomeMoreSection extends ConsumerWidget {
  const HomeMoreSection({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(preferencesProvider.select((p) => p.homeMoreOpen));
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('home-more'),
              leading: Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(tr('Habits, tips and fun')),
              subtitle: open
                  ? null
                  : Text(tr('Your streak, how the month felt, tips')),
              trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
              onTap: () => ref
                  .read(settingsRepositoryProvider)
                  .update((p) => p.copyWith(homeMoreOpen: !open)),
            ),
          ),
        ),
        if (open) ...children,
      ],
    );
  }
}
