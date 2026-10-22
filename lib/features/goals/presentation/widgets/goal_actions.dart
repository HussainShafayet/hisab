import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';

/// Asks whether to delete [item], and does it when the answer is yes. The goal
/// and its list of savings go; no account is touched. Returns true when it was
/// deleted.
Future<bool> confirmDeleteGoal(
  BuildContext context,
  WidgetRef ref,
  GoalWithSaved item,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Delete "{name}"?', {'name': item.goal.name})),
      content: Text(
        tr(
          'The goal and its list of savings are removed. Your accounts '
          'are not changed.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete-goal'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('Delete')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(goalsRepositoryProvider).deleteGoal(item.goal.id);
  return true;
}
