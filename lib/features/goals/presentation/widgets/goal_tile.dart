import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_hint.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_icons.dart';

/// A goal in the list: its icon and name, a progress bar, what is saved of the
/// target, and a line on what to do next.
class GoalTile extends StatelessWidget {
  const GoalTile({
    required this.item,
    required this.today,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final GoalWithSaved item;
  final DateTime today;
  final VoidCallback onTap;

  /// When both are given, the tile has a menu to edit or delete the goal.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final late = item.isLate(today);
    final percent = (item.fraction * 100).floor();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.isReached
                        ? colors.income.withValues(alpha: 0.15)
                        : theme.colorScheme.primaryContainer,
                    foregroundColor: item.isReached
                        ? colors.income
                        : theme.colorScheme.onPrimaryContainer,
                    child: Icon(
                      item.isReached
                          ? Icons.check
                          : goalIconData(item.goal.icon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    localizeDigits('$percent%'),
                    key: ValueKey('goal-percent-${item.goal.id}'),
                    style: theme.textTheme.titleSmall?.tabular,
                  ),
                  if (onEdit != null && onDelete != null)
                    PopupMenuButton<bool>(
                      key: ValueKey('goal-menu-${item.goal.id}'),
                      onSelected: (edit) => edit ? onEdit!() : onDelete!(),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: true, child: Text(tr('Edit'))),
                        PopupMenuItem(value: false, child: Text(tr('Delete'))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.fraction,
                  minHeight: 6,
                  color: item.isReached ? colors.income : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('{saved} of {target}', {
                  'saved': formatPoisha(item.saved),
                  'target': formatPoisha(item.goal.target),
                }),
                key: ValueKey('goal-amounts-${item.goal.id}'),
                style: theme.textTheme.bodyMedium?.tabular,
              ),
              const SizedBox(height: 2),
              Text(
                goalHint(item, today),
                key: ValueKey('goal-hint-${item.goal.id}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: late
                      ? colors.expense
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
