import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(appDatabaseProvider)),
);

/// The budgets of a month with what was spent. The argument must be the first
/// day of the month, so every screen asking for the same month shares one
/// stream.
final monthBudgetProvider = StreamProvider.autoDispose
    .family<MonthBudget, DateTime>(
      (ref, month) => ref.watch(budgetsRepositoryProvider).watchMonth(month),
    );
