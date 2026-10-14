import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/investments/data/investments_table.dart';
import 'package:hishab/features/investments/domain/investment.dart';

part 'investments_dao.g.dart';

/// An investment row with its sums, in poisha.
typedef InvestmentRowWithSums = ({
  InvestmentRow investment,
  int putIn,
  int profit,
  int takenBack,
});

@DriftAccessor(tables: [Investments, InvestmentEntries])
class InvestmentsDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentsDaoMixin {
  InvestmentsDao(super.attachedDatabase);

  Expression<int> _sumOf(InvestmentEntryKind kind) => investmentEntries.amount
      .sum(filter: investmentEntries.kind.equals(kind.name));

  JoinedSelectStatement<HasResultSet, dynamic> _withSums(
    Expression<int> putIn,
    Expression<int> profit,
    Expression<int> takenBack,
  ) {
    return select(investments).join([
        leftOuterJoin(
          investmentEntries,
          investmentEntries.investmentId.equalsExp(investments.id),
        ),
      ])
      ..addColumns([putIn, profit, takenBack])
      ..groupBy([investments.id])
      ..orderBy([OrderingTerm.asc(investments.id)]);
  }

  InvestmentRowWithSums _row(
    TypedResult row,
    Expression<int> putIn,
    Expression<int> profit,
    Expression<int> takenBack,
  ) => (
    investment: row.readTable(investments),
    putIn: row.read(putIn) ?? 0,
    profit: row.read(profit) ?? 0,
    takenBack: row.read(takenBack) ?? 0,
  );

  /// Every investment, oldest first, with what went in, came as profit and
  /// was taken back.
  Stream<List<InvestmentRowWithSums>> watchWithSums() {
    final putIn = _sumOf(InvestmentEntryKind.putIn);
    final profit = _sumOf(InvestmentEntryKind.profit);
    final takenBack = _sumOf(InvestmentEntryKind.takeBack);
    return _withSums(putIn, profit, takenBack).watch().map(
      (rows) => [for (final row in rows) _row(row, putIn, profit, takenBack)],
    );
  }

  Future<InvestmentRowWithSums?> getWithSums(int id) async {
    final putIn = _sumOf(InvestmentEntryKind.putIn);
    final profit = _sumOf(InvestmentEntryKind.profit);
    final takenBack = _sumOf(InvestmentEntryKind.takeBack);
    final query = _withSums(putIn, profit, takenBack)
      ..where(investments.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _row(row, putIn, profit, takenBack);
  }

  Future<InvestmentRow?> getInvestment(int id) =>
      (select(investments)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<InvestmentRow>> getAllInvestments() =>
      (select(investments)..orderBy([(i) => OrderingTerm.asc(i.id)])).get();

  Future<List<InvestmentEntryRow>> getAllEntries() => (select(
    investmentEntries,
  )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();

  /// The lines of an investment, oldest first.
  Future<List<InvestmentEntryRow>> getEntries(int investmentId) =>
      (select(investmentEntries)
            ..where((e) => e.investmentId.equals(investmentId))
            ..orderBy([(e) => OrderingTerm.asc(e.id)]))
          .get();

  /// The lines of an investment, newest first.
  Stream<List<InvestmentEntryRow>> watchEntries(int investmentId) =>
      (select(investmentEntries)
            ..where((e) => e.investmentId.equals(investmentId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.date),
              (e) => OrderingTerm.desc(e.id),
            ]))
          .watch();

  Future<InvestmentEntryRow?> getEntry(int id) => (select(
    investmentEntries,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertInvestment(InvestmentsCompanion investment) =>
      into(investments).insert(investment);

  Future<bool> updateInvestment(InvestmentRow investment) =>
      update(investments).replace(investment);

  /// Deletes the investment and, with it, its lines.
  Future<int> deleteInvestment(int id) =>
      (delete(investments)..where((i) => i.id.equals(id))).go();

  Future<int> insertEntry(InvestmentEntriesCompanion entry) =>
      into(investmentEntries).insert(entry);

  Future<int> deleteEntry(int id) =>
      (delete(investmentEntries)..where((e) => e.id.equals(id))).go();
}
