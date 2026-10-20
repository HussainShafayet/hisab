import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(appDatabaseProvider)),
);

/// How much of the overall budget of the month before was left, for the hint
/// under the carry over switch.
final lastMonthLeftoverProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, month) {
      ref.watch(dataChangesProvider);
      return ref.watch(budgetsRepositoryProvider).leftoverLastMonth(month);
    });

/// The budgets of a month with what was spent. The argument must be the first
/// day of the month, so every screen asking for the same month shares one
/// stream.
final monthBudgetProvider = StreamProvider.autoDispose
    .family<MonthBudget, DateTime>((ref, month) {
      // Starts again when carrying over is switched on or off.
      ref.watch(preferencesProvider.select((p) => p.budgetRollover));
      return ref.watch(budgetsRepositoryProvider).watchMonth(month);
    });
