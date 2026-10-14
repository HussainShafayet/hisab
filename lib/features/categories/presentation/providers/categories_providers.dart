import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/domain/category.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(appDatabaseProvider)),
);

/// All categories, income and expense, parents and sub-categories mixed. The
/// argument is "include archived".
final categoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, bool>(
      (ref, includeArchived) => ref
          .watch(categoriesRepositoryProvider)
          .watchCategories(includeArchived: includeArchived),
    );

/// How many default categories this install is missing, for the "add the
/// Bangladesh categories" row on the Categories screen.
final missingDefaultCountProvider = Provider.autoDispose<int>(
  (ref) =>
      missingDefaults(ref.watch(categoriesProvider(true)).value ?? const [])
          .length,
);
