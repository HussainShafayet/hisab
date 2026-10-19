import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/providers/challenges_providers.dart';
import 'package:hishab/features/challenges/presentation/widgets/challenge_format.dart';

/// On Home: the running challenge that ends soonest. Not shown when none is
/// running.
class ChallengeHomeCard extends ConsumerWidget {
  const ChallengeHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(challengesProvider).value ?? const [];
    final today = ref.read(clockProvider)();
    final running =
        items.where((i) => i.stateOn(today) == ChallengeState.active).toList()
          ..sort((a, b) {
            final byEnd = a.challenge.endDate.compareTo(b.challenge.endDate);
            return byEnd != 0
                ? byEnd
                : a.challenge.id.compareTo(b.challenge.id);
          });
    if (running.isEmpty) return const SizedBox.shrink();

    final item = running.first;
    final theme = Theme.of(context);
    final color = challengeColor(context, ChallengeState.active);

    return Card(
      key: const ValueKey('challenge-home-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.challenges),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Challenge'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (running.length > 1)
                    Text(
                      tr('+{n} more', {'n': running.length - 1}),
                      style: theme.textTheme.labelMedium,
                    ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.challenge.title,
                key: const ValueKey('challenge-home-title'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: challengeBarValue(item, today),
                  minHeight: 8,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                challengeStatusLine(item, today),
                key: const ValueKey('challenge-home-status'),
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
