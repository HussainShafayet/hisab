import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/goals/data/goals_table.dart';

part 'goals_dao.g.dart';

/// A goal row with the total of its entries, in poisha.
typedef GoalRowWithSaved = ({SavingsGoalRow goal, int saved});

@DriftAccessor(tables: [SavingsGoals, GoalEntries])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _withSaved(
    Expression<int> saved,
  ) {
    return select(savingsGoals).join([
        leftOuterJoin(
          goalEntries,
          goalEntries.goalId.equalsExp(savingsGoals.id),
        ),
      ])
      ..addColumns([saved])
      ..groupBy([savingsGoals.id])
      ..orderBy([OrderingTerm.asc(savingsGoals.id)]);
  }

  /// Every goal, oldest first, with what has been put aside for it.
  Stream<List<GoalRowWithSaved>> watchWithSaved() {
    final saved = goalEntries.amount.sum();
    return _withSaved(saved).watch().map(
      (rows) => [
        for (final row in rows)
          (goal: row.readTable(savingsGoals), saved: row.read(saved) ?? 0),
      ],
    );
  }

  Future<GoalRowWithSaved?> getWithSaved(int id) async {
    final saved = goalEntries.amount.sum();
    final query = _withSaved(saved)..where(savingsGoals.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null
        ? null
        : (goal: row.readTable(savingsGoals), saved: row.read(saved) ?? 0);
  }

  Future<List<SavingsGoalRow>> getAllGoals() =>
      (select(savingsGoals)..orderBy([(g) => OrderingTerm.asc(g.id)])).get();

  Future<List<GoalEntryRow>> getAllEntries() =>
      (select(goalEntries)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();

  /// The entries of a goal, newest first.
  Stream<List<GoalEntryRow>> watchEntries(int goalId) =>
      (select(goalEntries)
            ..where((e) => e.goalId.equals(goalId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.date),
              (e) => OrderingTerm.desc(e.id),
            ]))
          .watch();

  Future<GoalEntryRow?> getEntry(int id) =>
      (select(goalEntries)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertGoal(SavingsGoalsCompanion goal) =>
      into(savingsGoals).insert(goal);

  Future<bool> updateGoal(SavingsGoalRow goal) =>
      update(savingsGoals).replace(goal);

  /// Deletes the goal and, with it, its entries.
  Future<int> deleteGoal(int id) =>
      (delete(savingsGoals)..where((g) => g.id.equals(id))).go();

  Future<int> insertEntry(GoalEntriesCompanion entry) =>
      into(goalEntries).insert(entry);

  Future<int> deleteEntry(int id) =>
      (delete(goalEntries)..where((e) => e.id.equals(id))).go();
}
