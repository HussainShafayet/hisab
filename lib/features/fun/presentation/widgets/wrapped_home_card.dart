import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';
import 'package:hishab/features/fun/presentation/providers/wrapped_providers.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// On Home at the turn of the month: "Your October wrapped is ready". Not shown
/// when Fun mode is off, outside those days, or when nothing was written in
/// that month.
class WrappedHomeCard extends ConsumerWidget {
  const WrappedHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(preferencesProvider).funMode) return const SizedBox.shrink();
    final month = wrappedMonthFor(ref.watch(clockProvider)());
    if (month == null) return const SizedBox.shrink();
    final wrapped = ref.watch(wrappedProvider(month)).value;
    if (wrapped == null || wrapped.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('wrapped-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.wrapped(month)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Your {month} wrapped is ready', {
                    'month': monthLabel(month),
                  }),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
