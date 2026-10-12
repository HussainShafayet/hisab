import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/insights/data/insights_repository.dart';
import 'package:hishab/features/insights/domain/insights.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(appDatabaseProvider)),
);

/// The observations about this month, worked out again when anything they
/// depend on changes.
final insightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) {
  ref.watch(dataChangesProvider);
  ref.watch(recurringRulesProvider);
  return ref.watch(insightsRepositoryProvider).load(ref.read(clockProvider)());
});
