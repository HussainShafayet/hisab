import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/help/domain/guide.dart';
import 'package:hishab/features/help/domain/guide_content.dart';

/// One page of the guide.
class GuideTopicScreen extends StatelessWidget {
  const GuideTopicScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final topic = guideTopicById(guideTopics, topicId);
    if (topic == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Help & guide'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr('That page of the guide was not found.'),
              key: const ValueKey('guide-missing'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final route = topic.route;

    return Scaffold(
      appBar: AppBar(title: Text(tr(topic.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.primaryContainer,
                child: Icon(topic.icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  tr(topic.summary),
                  key: const ValueKey('guide-summary'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          for (final section in topic.sections) ...[
            const SizedBox(height: 24),
            Text(
              tr(section.heading),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, point) in section.points.indexed)
              _Point(text: tr(point), number: section.steps ? i + 1 : null),
          ],
          if (route != null) ...[
            const SizedBox(height: 28),
            FilledButton.tonalIcon(
              key: const ValueKey('guide-open'),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr('Open {name}', {'name': tr(topic.title)})),
              onPressed: () => route.startsWith('${AppRoutes.more}/')
                  ? context.push(route)
                  : context.go(route),
            ),
          ],
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text, this.number});

  final String text;

  /// The step number, or null for a bullet.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null)
            CircleAvatar(
              radius: 12,
              backgroundColor: colors.secondaryContainer,
              child: Text(
                '$number',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 4),
              child: Icon(Icons.circle, size: 7, color: colors.primary),
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
