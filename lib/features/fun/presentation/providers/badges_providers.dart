import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/providers/challenges_providers.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/fun/domain/badges.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/metals/presentation/providers/metals_providers.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';
import 'package:hishab/features/transactions/data/feeling_queries.dart';

/// The streaks and badges, again after any change to the data.
final badgeReportProvider = FutureProvider.autoDispose<BadgeReport>((
  ref,
) async {
  ref.watch(dataChangesProvider);
  final db = ref.watch(appDatabaseProvider);
  final goals = ref.watch(goalsProvider).value ?? const [];
  final debts = ref.watch(debtsProvider).value ?? const [];
  final metals = ref.watch(metalHoldingsProvider).value ?? const [];
  final challenges = ref.watch(challengesProvider).value ?? const [];
  final today = ref.read(clockProvider)();
  final facts = ActivityFacts(
    days: await db.activityDays(),
    markedExpenses: await db.markedExpenseCount(),
    lastRegret: await db.lastRegretDay(),
    goalReached: goals.any((g) => g.isReached),
    loanSettled: debts.any((d) => d.isSettled),
    hasMetals: metals.isNotEmpty,
    challengeWon: challenges.any((c) => c.stateOn(today) == ChallengeState.won),
  );
  return badgeReportOf(facts, today);
});
