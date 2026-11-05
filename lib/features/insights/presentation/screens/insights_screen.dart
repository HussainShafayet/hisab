import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/insights/presentation/insight_links.dart';
import 'package:hishab/features/insights/presentation/insight_text.dart';
import 'package:hishab/features/insights/presentation/providers/insights_providers.dart';
import 'package:hishab/features/insights/presentation/widgets/habits_and_tips.dart';

/// Everything the app has noticed about this month, the habits behind the
/// spending and a tip: the long version of the card on Home.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Insights & habits')),
        actions: const [HelpButton('fun')],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const TipCard(),
          insights.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(insightsProvider),
            ),
            data: (list) => Card(
              key: const ValueKey('insights-all'),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('This month'),
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          tr(
                            'Nothing to point out yet. Add a few more entries '
                            'and it will have something to say.',
                          ),
                          key: const ValueKey('no-insights'),
                        ),
                      ),
                    for (final insight in list) InsightRow(insight: insight),
                  ],
                ),
              ),
            ),
          ),
          const HabitsCard(),
        ],
      ),
    );
  }
}

/// One observation, with a chevron and a tap when it leads somewhere.
class InsightRow extends StatelessWidget {
  const InsightRow({required this.insight, super.key});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = insight.link != null;
    return InkWell(
      key: ValueKey('insight-row-${insight.kind.name}'),
      borderRadius: BorderRadius.circular(8),
      onTap: linked ? () => openInsight(context, insight) : null,
      child: Padding(
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
            if (linked)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
