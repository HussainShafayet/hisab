import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/fun/domain/badges.dart';
import 'package:hishab/features/fun/presentation/providers/badges_providers.dart';

IconData _iconOf(BadgeId id) => switch (id) {
  BadgeId.firstEntry => Icons.flag_outlined,
  BadgeId.streak3 => Icons.looks_3_outlined,
  BadgeId.streak7 => Icons.date_range_outlined,
  BadgeId.streak30 => Icons.emoji_events_outlined,
  BadgeId.spendFreeDay => Icons.nightlight_outlined,
  BadgeId.spendFree10 => Icons.savings_outlined,
  BadgeId.selfAware => Icons.self_improvement,
  BadgeId.regretFreeWeek => Icons.sentiment_very_satisfied_outlined,
  BadgeId.goalReached => Icons.star_outline,
  BadgeId.loanSettled => Icons.handshake_outlined,
  BadgeId.goldKeeper => Icons.diamond_outlined,
};

/// Takka's badges: the streaks, and every badge with how to win it. The ones
/// not won yet are grey.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(badgeReportProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Badges'))),
      body: report.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('{n} of {total} badges', {
                        'n': data.earned,
                        'total': data.badges.length,
                      }),
                      key: const ValueKey('badges-count'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plural(
                        data.streak,
                        '1 day in a row',
                        '{n} days in a row',
                      ),
                    ),
                    Text(
                      tr('Best: {n} days in a row', {'n': data.bestStreak}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final badge in data.badges)
              ListTile(
                key: ValueKey('badge-${badge.id.name}'),
                leading: CircleAvatar(
                  backgroundColor: badge.earned
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: badge.earned
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.disabledColor,
                  child: Icon(badge.earned ? _iconOf(badge.id) : Icons.lock),
                ),
                title: Text(badgeTitle(badge.id)),
                subtitle: Text(badgeHowTo(badge.id)),
                trailing: badge.earned
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
