import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/providers/challenges_providers.dart';
import 'package:hishab/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:hishab/features/fun/presentation/celebrate.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// The spending challenges: the ones running, the ones coming and the ones
/// that are over.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _checkedWins = false;

  @override
  void initState() {
    super.initState();
    // A challenge that was won since the last visit gets its confetti, once.
    ref.listenManual(challengesProvider, (_, next) {
      final list = next.value;
      if (list == null || _checkedWins) return;
      _checkedWins = true;
      ref
          .read(challengesRepositoryProvider)
          .takeNewWins(list, ref.read(clockProvider)())
          .then((cheer) {
            if (cheer && mounted) celebrate(context, ref);
          });
    }, fireImmediately: true);
  }

  Future<void> _delete(ChallengeItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete this challenge?')),
        content: Text(
          tr('"{name}" is removed for good. Your spending is not touched.', {
            'name': item.challenge.title,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-challenge'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(challengesRepositoryProvider).delete(item.challenge.id);
      messenger.showMessage(tr('Challenge deleted'));
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(challengesProvider);
    final today = ref.read(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Challenges')),
        actions: const [HelpButton('challenges')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-challenge'),
        onPressed: () => context.push(AppRoutes.newChallenge),
        icon: const Icon(Icons.add),
        label: Text(tr('New challenge')),
      ),
      body: items.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.timer_outlined,
              title: tr('No challenges yet'),
              message: tr(
                'Dare yourself: a week without rickshaw, or a month under a '
                'limit. Takka will be watching.',
              ),
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.newChallenge),
                child: Text(tr('New challenge')),
              ),
            );
          }
          List<ChallengeItem> inState(Set<ChallengeState> states) => [
            for (final item in list)
              if (states.contains(item.stateOn(today))) item,
          ];
          final sections = [
            (tr('Running now'), inState({ChallengeState.active})),
            (tr('Coming up'), inState({ChallengeState.upcoming})),
            (
              tr('Finished'),
              inState({ChallengeState.won, ChallengeState.broken}),
            ),
          ];

          var arrived = 0;
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              for (final (title, group) in sections)
                if (group.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final item in group)
                    arriving(
                      arrived++,
                      ChallengeTile(
                        item: item,
                        today: today,
                        onEdit: () => context.push(
                          AppRoutes.editChallenge(item.challenge.id),
                        ),
                        onDelete: () => _delete(item),
                      ),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}
