import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/data/feeling_queries.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';

/// How this month's spending felt, again after any change to the data.
final feelingSummaryProvider = FutureProvider.autoDispose<FeelingSummary>((
  ref,
) async {
  ref.watch(dataChangesProvider);
  final db = ref.watch(appDatabaseProvider);
  final range = monthRange(ref.read(clockProvider)());
  return FeelingSummary.of(
    await db.expenseByFeeling(range.start, range.end),
    lastRegret: await db.lastRegretDay(),
    markedEver: await db.markedExpenseCount(),
  );
});
