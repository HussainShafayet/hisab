import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/insights/presentation/insight_text.dart';
import 'package:hishab/features/insights/presentation/providers/insights_providers.dart';

/// Short observations about this month: what changed, what is coming. Shows
/// nothing while loading or when there is nothing to say.
class InsightsCard extends ConsumerWidget {
  const InsightsCard({this.max = 4, super.key});

  /// How many to show at most.
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = (ref.watch(insightsProvider).value ?? const <Insight>[])
        .take(max)
        .toList();
    if (insights.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('insights'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(tr('Insights'), style: theme.textTheme.titleSmall),
              ],
            ),
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      insightIcon(insight.kind),
                      size: 20,
                      color: insightColor(context, insight.tone),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insightText(insight),
                        key: ValueKey('insight-${insight.kind.name}'),
                        style: theme.textTheme.bodyMedium,
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
}
