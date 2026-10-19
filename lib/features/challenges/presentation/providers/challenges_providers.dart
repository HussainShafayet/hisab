import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/challenges/data/challenges_repository.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

final challengesRepositoryProvider = Provider<ChallengesRepository>(
  (ref) => ChallengesRepository(ref.watch(appDatabaseProvider)),
);

/// Every challenge, the latest start first, with what was spent in it. Updates
/// when a challenge or an expense changes.
final challengesProvider = StreamProvider<List<ChallengeItem>>(
  (ref) => ref.watch(challengesRepositoryProvider).watchChallenges(),
);
