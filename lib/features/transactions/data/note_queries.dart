import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/transactions/domain/note_suggestion.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The notes people wrote, for suggesting them again.
extension NoteQueries on AppDatabase {
  /// The newest income and expense entries that have a note, newest first, at
  /// most [limit]. Transfers and balance adjustments are not asked about.
  Future<List<PastNote>> pastNotes({int limit = 400}) async {
    final rows =
        await (select(transactions)
              ..where(
                (t) =>
                    t.note.equals('').not() &
                    t.isAdjustment.equals(false) &
                    t.type.equals(TransactionType.transfer.name).not(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.date),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        PastNote(
          note: row.note,
          type: row.type,
          amount: row.amount,
          categoryId: row.categoryId,
        ),
    ];
  }

  /// An entry whose note holds [text], for telling that a message with this
  /// transaction id was already added. Null when there is none.
  Future<TransactionRow?> entryWithNote(String text) =>
      (select(transactions)
            ..where((t) => t.note.like('%$text%'))
            ..limit(1))
          .getSingleOrNull();
}
