import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/widgets/challenge_format.dart';
import 'package:intl/intl.dart';

/// A challenge in the list: its name, where it stands and a bar.
class ChallengeTile extends StatelessWidget {
  const ChallengeTile({
    required this.item,
    required this.today,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ChallengeItem item;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// `11 Oct – 17 Oct`, with the year when it is not this one.
  String _period() {
    final c = item.challenge;
    final year = c.startDate.year == today.year && c.endDate.year == today.year;
    final format = DateFormat(year ? 'd MMM' : 'd MMM yyyy');
    return '${format.format(c.startDate)} – ${format.format(c.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = item.stateOn(today);
    final color = challengeColor(context, state);
    final scope = item.categoryName ?? tr('All spending');

    return Card(
      key: ValueKey('challenge-${item.challenge.id}'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(challengeIcon(state), color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.challenge.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: ValueKey('challenge-menu-${item.challenge.id}'),
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: const ValueKey('challenge-edit'),
                        value: 'edit',
                        child: Text(tr('Edit')),
                      ),
                      PopupMenuItem(
                        key: const ValueKey('challenge-delete'),
                        value: 'delete',
                        child: Text(tr('Delete')),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$scope · ${_period()}'
                      '${item.challenge.repeats ? ' · ${tr('Repeats')}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: challengeBarValue(item, today),
                        minHeight: 8,
                        color: color,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      challengeStatusLine(item, today),
                      key: ValueKey('challenge-status-${item.challenge.id}'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
