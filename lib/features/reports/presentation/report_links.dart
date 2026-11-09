import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/features/transactions/presentation/open_entries.dart';

/// The entries behind a row of a report: one tap from a number to the
/// transactions that make it up.
class ReportLinks {
  const ReportLinks._();

  /// The entries of [categoryId] (and everything inside it) of [type] in
  /// [range].
  static Future<void> category(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    required String name,
    required DateRange range,
    required TransactionType type,
    bool ownOnly = false,
  }) async {
    // Read now: the categories provider has no value unless a screen watches
    // it, and without them the entries of sub-categories would be left out.
    final all = await ref
        .read(categoriesRepositoryProvider)
        .getCategories(includeArchived: true);
    if (!context.mounted) return;
    return openEntries(
      context,
      title: name,
      filter: TransactionFilter(
        range: range,
        type: type,
        categoryId: categoryId,
        categoryScope: ownOnly
            ? {categoryId}
            : categoryAndDescendantIds(categoryId, all),
      ),
    );
  }

  /// The entries that touched [accountId] in [range].
  static Future<void> account(
    BuildContext context, {
    required int accountId,
    required String name,
    required DateRange range,
  }) => openEntries(
    context,
    title: name,
    filter: TransactionFilter(range: range, accountId: accountId),
  );

  /// All the income or all the expenses of [range].
  static Future<void> type(
    BuildContext context, {
    required String title,
    required TransactionType type,
    required DateRange range,
  }) => openEntries(
    context,
    title: title,
    filter: TransactionFilter(range: range, type: type),
  );

  /// Everything of one day.
  static Future<void> day(
    BuildContext context, {
    required String title,
    required DateTime day,
    TransactionType? type,
  }) => openEntries(
    context,
    title: title,
    filter: TransactionFilter(
      range: (
        start: dateOnly(day),
        end: DateTime(day.year, day.month, day.day + 1),
      ),
      type: type,
    ),
  );
}
