import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/challenges/data/challenges_table.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:hishab/core/database/category_tree_sql.dart';

part 'challenges_dao.g.dart';

/// A challenge row with its category's name and what was spent in it.
typedef ChallengeWithSpent = ({
  ChallengeRow challenge,
  String? categoryName,
  int spent,
});

@DriftAccessor(tables: [Challenges])
class ChallengesDao extends DatabaseAccessor<AppDatabase>
    with _$ChallengesDaoMixin {
  ChallengesDao(super.attachedDatabase);

  Future<List<ChallengeRow>> getAll() =>
      (select(challenges)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

  Future<ChallengeRow?> getById(int id) =>
      (select(challenges)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertChallenge(ChallengesCompanion row) =>
      into(challenges).insert(row);

  Future<bool> updateChallenge(ChallengeRow row) =>
      update(challenges).replace(row);

  Future<int> deleteChallenge(int id) =>
      (delete(challenges)..where((c) => c.id.equals(id))).go();

  /// Every challenge, the latest start first, with what was spent in it. Emits
  /// again when a challenge, a category or a transaction changes.
  ///
  /// What counts as spent: expenses of its days (a day runs from midnight to
  /// midnight), in its category and everything inside it at any depth, or all
  /// of them for a challenge without a category. Transfers and balance
  /// adjustments are not spending.
  Stream<List<ChallengeWithSpent>> watchWithSpent() => _select(null).watch();

  Future<ChallengeWithSpent?> getWithSpent(int id) async {
    final rows = await _select(id).get();
    return rows.isEmpty ? null : rows.single;
  }

  Selectable<ChallengeWithSpent> _select(int? id) {
    // The type name comes from our own enum, never from user input.
    final expense = TransactionType.expense.name;
    String spent(String extraCondition) =>
        '(SELECT COALESCE(SUM(t.amount), 0) FROM transactions t '
        "WHERE t.type = '$expense' AND t.is_adjustment = 0 "
        'AND t.date >= c.start_date AND t.date < c.end_date + 86400 '
        '$extraCondition)';

    return customSelect(
      '${categoryTreeCte}SELECT c.id, c.title, c.kind, c.category_id, '
      'c.limit_amount, c.start_date, c.end_date, c.created_at, '
      'cat.name AS category_name, '
      'CASE WHEN c.category_id IS NULL THEN ${spent('')} '
      'ELSE ${spent('AND t.category_id IN '
      '(SELECT id FROM category_tree WHERE root_id = c.category_id)')} '
      'END AS spent '
      'FROM challenges c LEFT JOIN categories cat ON cat.id = c.category_id '
      '${id == null ? '' : 'WHERE c.id = ? '}'
      'ORDER BY c.start_date DESC, c.id DESC',
      variables: [if (id != null) Variable.withInt(id)],
      readsFrom: {
        challenges,
        attachedDatabase.transactions,
        attachedDatabase.categories,
      },
    ).map(
      (row) => (
        challenge: ChallengeRow(
          id: row.read<int>('id'),
          title: row.read<String>('title'),
          kind: ChallengeKind.values.byName(row.read<String>('kind')),
          categoryId: row.readNullable<int>('category_id'),
          limitAmount: row.read<int>('limit_amount'),
          startDate: row.read<DateTime>('start_date'),
          endDate: row.read<DateTime>('end_date'),
          createdAt: row.read<DateTime>('created_at'),
        ),
        categoryName: row.readNullable<String>('category_name'),
        spent: row.read<int>('spent'),
      ),
    );
  }
}
