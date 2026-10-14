import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/fun/presentation/providers/badges_providers.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// On Home: how many days in a row entries were written, the days with no
/// spending this month and how many badges are won. A tap opens the badges.
/// Not shown when Fun mode is off.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(preferencesProvider).funMode) return const SizedBox.shrink();
    final report = ref.watch(badgeReportProvider).value;
    if (report == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final lit = report.streak > 0;
    final lines = [
      lit
          ? plural(report.streak, '1 day in a row', '{n} days in a row')
          : tr('Write an entry today to start a streak!'),
      if (report.spendFreeThisMonth > 0)
        plural(
          report.spendFreeThisMonth,
          '1 spend-free day this month',
          '{n} spend-free days this month',
        ),
    ];

    return Card(
      key: const ValueKey('streak-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.badges),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 32,
                color: lit ? Colors.deepOrange : theme.disabledColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines.first,
                      key: const ValueKey('streak-days'),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (lines.length > 1)
                      Text(
                        lines[1],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                tr('{n} of {total} badges', {
                  'n': report.earned,
                  'total': report.badges.length,
                }),
                key: const ValueKey('streak-badges'),
                style: theme.textTheme.labelMedium,
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
