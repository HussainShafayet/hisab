import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/dashboard/data/dashboard_repository.dart';
import 'package:hishab/features/dashboard/domain/dashboard_data.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(appDatabaseProvider)),
);

/// What the Home screen shows. It is calculated again after any change to
/// the data (a new transaction, a budget edit, ...).
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  ref.watch(dataChangesProvider);
  return ref.watch(dashboardRepositoryProvider).load(ref.read(clockProvider)());
});
