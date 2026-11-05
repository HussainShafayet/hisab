import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/insights/domain/habits.dart';
import 'package:hishab/features/insights/presentation/providers/insights_providers.dart';
import 'package:hishab/core/database/database_provider.dart';

/// What is spent on again and again, worked out again when anything changes.
final habitsProvider = FutureProvider.autoDispose<List<Habit>>((ref) {
  ref.watch(dataChangesProvider);
  return ref
      .watch(insightsRepositoryProvider)
      .habits(ref.read(clockProvider)());
});
