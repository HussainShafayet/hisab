import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/tags/data/tags_table.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'tags_dao.g.dart';

/// A tag with the sums of the transactions that carry it.
typedef TagSummaryRow = ({
  TagRow tag,
  int expense,
  int income,
  int count,
  DateTime? firstDate,
  DateTime? lastDate,
});

@DriftAccessor(tables: [Tags, Transactions])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.attachedDatabase);

  Stream<List<TagRow>> watchAll() =>
      (select(tags)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  Future<List<TagRow>> getAll() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<TagRow?> getById(int id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The tag called [name], whatever the case, if there is one.
  Future<TagRow?> findByName(String name) => (select(
    tags,
  )..where((t) => t.name.lower().equals(name.toLowerCase()))).getSingleOrNull();

  Future<int> insertTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<bool> updateTag(TagRow tag) => update(tags).replace(tag);

  /// Deletes the tag. Its transactions stay, without a tag.
  Future<int> deleteTag(int id) async {
    await customUpdate(
      'UPDATE transactions SET tag_id = NULL WHERE tag_id = ?',
      variables: [Variable.withInt(id)],
      updates: {transactions},
      updateKind: UpdateKind.update,
    );
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// Every tag with what was spent and received under it, the one used most
  /// recently first.
  Stream<List<TagSummaryRow>> watchSummaries() {
    final expense = TransactionType.expense.name;
    final income = TransactionType.income.name;
    return customSelect(
      'SELECT g.id AS id, g.name AS name, g.created_at AS created_at, '
      "COALESCE(SUM(CASE WHEN t.type = '$expense' AND t.is_adjustment = 0 "
      'THEN t.amount END), 0) AS expense, '
      "COALESCE(SUM(CASE WHEN t.type = '$income' AND t.is_adjustment = 0 "
      'THEN t.amount END), 0) AS income, '
      'COUNT(t.id) AS uses, MIN(t.date) AS first_date, MAX(t.date) AS last_date '
      'FROM tags g LEFT JOIN transactions t ON t.tag_id = g.id '
      'GROUP BY g.id ORDER BY COALESCE(MAX(t.date), 0) DESC, g.id DESC',
      readsFrom: {tags, transactions},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          (
            tag: TagRow(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              createdAt: row.read<DateTime>('created_at'),
            ),
            expense: row.read<int>('expense'),
            income: row.read<int>('income'),
            count: row.read<int>('uses'),
            firstDate: row.readNullable<DateTime>('first_date'),
            lastDate: row.readNullable<DateTime>('last_date'),
          ),
      ],
    );
  }
}
