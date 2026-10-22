import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/data_check/domain/data_check.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

/// What looks wrong in the entries, looked for again after any change to the
/// data.
final dataCheckProvider = FutureProvider.autoDispose<DataCheck>((ref) async {
  ref.watch(dataChangesProvider);
  final transactions = await ref
      .watch(transactionsRepositoryProvider)
      .getBetween(DateTime(2000), DateTime(2100));
  final categories = await ref
      .watch(categoriesRepositoryProvider)
      .getCategories();
  return checkData(
    transactions: transactions,
    categories: categories,
    now: ref.read(clockProvider)(),
  );
});
