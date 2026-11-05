import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';

/// What the list of entries opened from a report or a card starts with.
class FilteredEntriesArgs {
  const FilteredEntriesArgs({required this.title, required this.filter});

  final String title;
  final TransactionFilter filter;
}

/// Opens the transactions that match [filter] on a screen of their own, with
/// a back button, the search, the type chips and everything else of the list.
Future<void> openEntries(
  BuildContext context, {
  required String title,
  required TransactionFilter filter,
}) => context.push(
  AppRoutes.entries,
  extra: FilteredEntriesArgs(title: title, filter: filter),
);
