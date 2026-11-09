import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/presentation/providers/budget_providers.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/transactions/domain/category_standing.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Which category, of which kind, in which month. [month] is the first day.
typedef CategoryStandingKey = ({
  int categoryId,
  TransactionType type,
  DateTime month,
});

/// What a category holds this month and which budget covers it, for the entry
/// form. Calculated again after any change in the data.
final categoryStandingProvider = FutureProvider.autoDispose
    .family<CategoryStanding, CategoryStandingKey>((ref, key) async {
      ref.watch(dataChangesProvider);
      final db = ref.read(appDatabaseProvider);
      final range = monthRange(key.month);
      final categories = await ref
          .read(categoriesRepositoryProvider)
          .getCategories(includeArchived: true);
      final own = await db.reportsDao.ownTotalsByCategory(
        key.type,
        range.start,
        range.end,
      );
      final ids = categoryAndDescendantIds(key.categoryId, categories);
      final total = ids.fold<int>(0, (sum, id) => sum + (own[id] ?? 0));
      if (key.type != TransactionType.expense) {
        return CategoryStanding(total: total);
      }
      final month = await ref.watch(monthBudgetProvider(range.start).future);
      return CategoryStanding(
        total: total,
        budget: budgetCovering(key.categoryId, {
          for (final category in categories) category.id: category,
        }, month.categories),
      );
    });
