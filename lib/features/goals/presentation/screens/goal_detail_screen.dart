import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/features/fun/presentation/celebrate.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_actions.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_hint.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_icons.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_money_dialog.dart';
import 'package:intl/intl.dart';

enum _GoalAction { edit, delete }

/// One goal: how far it has come, what to put aside next, and every time
/// money went in or out.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});

  final int goalId;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    GoalWithSaved item,
    _GoalAction action,
  ) async {
    switch (action) {
      case _GoalAction.edit:
        await context.push(AppRoutes.editGoal(item.goal.id));
      case _GoalAction.delete:
        if (await confirmDeleteGoal(context, ref, item) && context.mounted) {
          context.pop();
        }
    }
  }

  Future<void> _addMoney(
    BuildContext context,
    WidgetRef ref, {
    required bool putIn,
  }) async {
    final money = await showGoalMoneyDialog(
      context,
      putIn: putIn,
      today: ref.read(clockProvider)(),
    );
    if (money == null) return;
    try {
      final repository = ref.read(goalsRepositoryProvider);
      final wasReached = (await repository.getGoal(goalId))?.isReached ?? false;
      await repository.addEntry(
        goalId,
        amount: putIn ? money.amount : -money.amount,
        date: money.date,
        note: money.note,
      );
      // The money that makes the goal: a little celebration.
      final isReached = (await repository.getGoal(goalId))?.isReached ?? false;
      if (putIn && isReached && !wasReached && context.mounted) {
        celebrate(context, ref);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showError(describeError(e));
      }
    }
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    GoalEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Remove this entry?')),
        content: Text(
          tr('{amount} will no longer count towards the goal.', {
            'amount': formatPoisha(entry.amount.abs()),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-entry'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(goalsRepositoryProvider).deleteEntry(entry.id);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showError(describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final today = ref.watch(clockProvider)();

    return goals.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(tr('Savings goal'))),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(tr('Savings goal'))),
        body: ErrorView(message: describeError(error)),
      ),
      data: (list) {
        final item = list.where((g) => g.goal.id == goalId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('Savings goal'))),
            body: ErrorView(message: tr('This goal no longer exists.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(item.goal.name),
            actions: [
              PopupMenuButton<_GoalAction>(
                key: const ValueKey('goal-menu'),
                onSelected: (action) => _onAction(context, ref, item, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _GoalAction.edit,
                    child: Text(tr('Edit')),
                  ),
                  PopupMenuItem(
                    value: _GoalAction.delete,
                    child: Text(tr('Delete')),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _Header(item: item, today: today),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('put-in'),
                        onPressed: () => _addMoney(context, ref, putIn: true),
                        icon: const Icon(Icons.add),
                        label: Text(tr('Put money in')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('take-out'),
                        onPressed: item.saved > 0
                            ? () => _addMoney(context, ref, putIn: false)
                            : null,
                        icon: const Icon(Icons.remove),
                        label: Text(tr('Take out')),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  tr(
                    'This money stays in your accounts. Goals only remind '
                    'you what it is for.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _Entries(
                goalId: goalId,
                onDelete: (entry) => _deleteEntry(context, ref, entry),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.today});

  final GoalWithSaved item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final perWeek = item.perWeek(today);
    final day = item.goal.targetDate;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: item.isReached
                    ? colors.income.withValues(alpha: 0.15)
                    : theme.colorScheme.primaryContainer,
                foregroundColor: item.isReached
                    ? colors.income
                    : theme.colorScheme.onPrimaryContainer,
                child: Icon(
                  item.isReached ? Icons.check : goalIconData(item.goal.icon),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPoisha(item.saved),
                      key: const ValueKey('goal-saved'),
                      style: theme.textTheme.headlineSmall?.tabular.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      tr('of {target}', {
                        'target': formatPoisha(item.goal.target),
                      }),
                      key: const ValueKey('goal-target-text'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                localizeDigits('${(item.fraction * 100).floor()}%'),
                key: const ValueKey('goal-percent'),
                style: theme.textTheme.titleLarge?.tabular,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.fraction,
              minHeight: 10,
              color: item.isReached ? colors.income : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            goalHint(item, today),
            key: const ValueKey('goal-hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: item.isLate(today) ? colors.expense : null,
            ),
          ),
          if (perWeek != null)
            Text(
              tr('About {amount} a week', {'amount': formatPoisha(perWeek)}),
              key: const ValueKey('goal-per-week'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (day != null && !item.isReached)
            Text(
              tr('{days} days left', {'days': item.daysLeft(today) ?? 0}),
              key: const ValueKey('goal-days-left'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Entries extends ConsumerWidget {
  const _Entries({required this.goalId, required this.onDelete});

  final int goalId;
  final void Function(GoalEntry entry) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final entries = ref.watch(goalEntriesProvider(goalId)).value ?? const [];
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            tr('Nothing put in yet.'),
            key: const ValueKey('no-entries'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(tr('History'), style: theme.textTheme.titleSmall),
        ),
        for (final entry in entries)
          ListTile(
            key: ValueKey('entry-${entry.id}'),
            leading: Icon(
              entry.isTakeOut ? Icons.arrow_upward : Icons.arrow_downward,
              color: entry.isTakeOut ? colors.expense : colors.income,
            ),
            title: Text(
              '${entry.isTakeOut ? '-' : '+'}'
              '${formatPoisha(entry.amount.abs())}',
              style: theme.textTheme.titleSmall?.tabular.copyWith(
                color: entry.isTakeOut ? colors.expense : colors.income,
              ),
            ),
            subtitle: Text(
              [
                DateFormat('d MMM yyyy').format(entry.date),
                if (entry.note.isNotEmpty) entry.note,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              key: ValueKey('delete-entry-${entry.id}'),
              tooltip: tr('Remove'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(entry),
            ),
          ),
      ],
    );
  }
}
