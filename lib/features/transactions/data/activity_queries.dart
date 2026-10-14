import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Which days had an entry. Balance adjustments are not entries the person
/// wrote, so they do not count.
extension ActivityQueries on AppDatabase {
  /// Every local day with an entry, and whether an expense was written that
  /// day, as dates at midnight.
  Future<Map<DateTime, bool>> activityDays() async {
    final rows = await customSelect(
      "SELECT date(date, 'unixepoch', 'localtime') AS day, "
      "MAX(CASE WHEN type = '${TransactionType.expense.name}' "
      'THEN 1 ELSE 0 END) AS spent '
      'FROM transactions WHERE is_adjustment = 0 GROUP BY day',
      readsFrom: {transactions},
    ).get();
    return {
      for (final row in rows)
        DateTime.parse(row.read<String>('day')): row.read<int>('spent') == 1,
    };
  }
}

/// How many entries were written in a period.
extension EntryCountQueries on AppDatabase {
  /// The entries (balance adjustments left out) in `start <= date < end`.
  Future<int> entryCount(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM transactions '
      'WHERE is_adjustment = 0 AND date >= ? AND date < ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactions},
    ).getSingle();
    return row.read<int>('n');
  }
}
