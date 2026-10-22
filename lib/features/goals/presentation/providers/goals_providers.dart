import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/goals/data/festival_settings_repository.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';
import 'package:hishab/features/goals/domain/festival_settings.dart';
import 'package:hishab/features/goals/domain/goal.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(appDatabaseProvider)),
);

final festivalSettingsRepositoryProvider = Provider<FestivalSettingsRepository>(
  (ref) => FestivalSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The festivals the person hid, and the days they set by hand.
final festivalSettingsProvider = StreamProvider<FestivalSettings>(
  (ref) => ref.watch(festivalSettingsRepositoryProvider).watch(),
);

/// Every goal, oldest first, with what has been put aside for it.
final goalsProvider = StreamProvider<List<GoalWithSaved>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchGoals(),
);

/// The money put in and taken out of one goal, newest first.
final goalEntriesProvider = StreamProvider.autoDispose
    .family<List<GoalEntry>, int>(
      (ref, goalId) => ref.watch(goalsRepositoryProvider).watchEntries(goalId),
    );
