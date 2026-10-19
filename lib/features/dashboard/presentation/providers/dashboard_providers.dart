import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/dashboard/data/dashboard_repository.dart';
import 'package:hishab/features/dashboard/domain/dashboard_data.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(appDatabaseProvider)),
);

/// What the Home screen shows. It is calculated again after any change to
/// the data (a new transaction, a budget edit, ...).
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  ref.watch(dataChangesProvider);
  // The budget limit includes what was carried over, when that is on.
  ref.watch(preferencesProvider.select((p) => p.budgetRollover));
  // "This week" starts on the day chosen in Settings.
  final weekStart = ref.watch(
    preferencesProvider.select((preferences) => preferences.weekStart.weekday),
  );
  return ref
      .watch(dashboardRepositoryProvider)
      .load(ref.read(clockProvider)(), firstWeekday: weekStart);
});
