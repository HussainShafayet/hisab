import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/goals/presentation/widgets/festival_tile.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_tile.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// The things being saved up for, with how far each one has come.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final today = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Savings goals')),
        actions: const [HelpButton('goals')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newGoal),
        icon: const Icon(Icons.add),
        label: Text(tr('New goal')),
      ),
      body: goals.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) {
          final festivals = upcomingFestivals(today, list);
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                _Festivals(festivals: festivals, today: today),
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.flag_outlined,
                    title: tr('No goals yet'),
                    message: tr(
                      'Save up for a laptop, a trip or Eid. Set a target and '
                      'put money aside a little at a time.',
                    ),
                    action: FilledButton(
                      onPressed: () => context.push(AppRoutes.newGoal),
                      child: Text(tr('New goal')),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              arriving(0, _Festivals(festivals: festivals, today: today)),
              arriving(1, _Summary(goals: list)),
              for (final (index, item) in list.indexed)
                arriving(
                  index + 2,
                  GoalTile(
                    key: ValueKey('goal-${item.goal.id}'),
                    item: item,
                    today: today,
                    onTap: () => context.push(AppRoutes.goal(item.goal.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The festivals coming up, each with its fund or a button to start one.
class _Festivals extends StatelessWidget {
  const _Festivals({required this.festivals, required this.today});

  final List<UpcomingFestival> festivals;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(tr('Coming up'), style: theme.textTheme.titleSmall),
        ),
        for (final item in festivals) FestivalTile(item: item, today: today),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            tr('The days of Eid are a guess: the moon decides.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// All the goals together: what is put aside of what they want.
class _Summary extends StatelessWidget {
  const _Summary({required this.goals});

  final List<GoalWithSaved> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = totalSaved(goals);
    final target = totalTarget(goals);
    final reached = goals.where((g) => g.isReached).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Put aside so far'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            formatPoisha(saved),
            key: const ValueKey('goals-saved'),
            style: theme.textTheme.headlineSmall?.tabular.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            tr('of {target} in {goals}, {reached} reached', {
              'target': formatPoisha(target),
              'goals': plural(goals.length, '1 goal', '{n} goals'),
              'reached': reached,
            }),
            key: const ValueKey('goals-summary'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'This money stays in your accounts. Goals only remind you what '
              'it is for.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
