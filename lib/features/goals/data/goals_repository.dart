import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/goals/data/goals_dao.dart';
import 'package:hishab/features/goals/domain/goal.dart';

/// Everything the UI needs for savings goals: reading them with what has been
/// put aside, and making, changing and deleting them and their entries with
/// the rules checked in one place.
class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  static const maxNoteLength = 200;

  /// Every goal, oldest first, with what has been put aside for it.
  Stream<List<GoalWithSaved>> watchGoals() => _db.goalsDao.watchWithSaved().map(
    (rows) => rows.map(_toGoalWithSaved).toList(),
  );

  Future<GoalWithSaved?> getGoal(int id) async {
    final row = await _db.goalsDao.getWithSaved(id);
    return row == null ? null : _toGoalWithSaved(row);
  }

  /// The money put in and taken out of goal [goalId], newest first.
  Stream<List<GoalEntry>> watchEntries(int goalId) => _db.goalsDao
      .watchEntries(goalId)
      .map((rows) => rows.map(_toEntry).toList());

  /// Returns the new goal's id.
  Future<int> createGoal({
    required String name,
    required int target,
    DateTime? targetDate,
    String icon = defaultGoalIcon,
  }) {
    final clean = _validated(name, target);
    return _db.goalsDao.insertGoal(
      SavingsGoalsCompanion.insert(
        name: clean,
        target: target,
        targetDate: Value(targetDate == null ? null : dateOnly(targetDate)),
        icon: Value(_iconOrDefault(icon)),
      ),
    );
  }

  Future<void> updateGoal(
    int id, {
    required String name,
    required int target,
    DateTime? targetDate,
    String icon = defaultGoalIcon,
  }) async {
    final current = await _db.goalsDao.getWithSaved(id);
    if (current == null) throw ValidationException(tr('Goal not found.'));
    final clean = _validated(name, target);
    await _db.goalsDao.updateGoal(
      current.goal.copyWith(
        name: clean,
        target: target,
        targetDate: Value(targetDate == null ? null : dateOnly(targetDate)),
        icon: _iconOrDefault(icon),
      ),
    );
  }

  /// Deletes the goal and everything put into it. No account is touched.
  Future<void> deleteGoal(int id) async {
    await _db.goalsDao.deleteGoal(id);
  }

  /// Puts [amount] into goal [goalId] (above zero), or takes it out (below
  /// zero). Taking out more than is saved is refused. Returns the entry's id.
  Future<int> addEntry(
    int goalId, {
    required int amount,
    required DateTime date,
    String note = '',
  }) {
    return _db.transaction(() async {
      final goal = await _db.goalsDao.getWithSaved(goalId);
      if (goal == null) throw ValidationException(tr('Goal not found.'));
      if (amount == 0) {
        throw ValidationException(tr('The amount cannot be zero.'));
      }
      if (note.trim().length > maxNoteLength) {
        throw ValidationException(
          tr('The note must be {max} characters or fewer.', {
            'max': maxNoteLength,
          }),
        );
      }
      if (goal.saved + amount < 0) {
        throw ValidationException(
          tr('Only {amount} is saved in this goal.', {
            'amount': formatPoisha(goal.saved),
          }),
        );
      }
      return _db.goalsDao.insertEntry(
        GoalEntriesCompanion.insert(
          goalId: goalId,
          amount: amount,
          date: dateOnly(date),
          note: Value(note.trim()),
        ),
      );
    });
  }

  /// Removes one entry. Refused when what was taken out afterwards would then
  /// be more than what is left.
  Future<void> deleteEntry(int id) {
    return _db.transaction(() async {
      final entry = await _db.goalsDao.getEntry(id);
      if (entry == null) return;
      final goal = await _db.goalsDao.getWithSaved(entry.goalId);
      if (goal != null && goal.saved - entry.amount < 0) {
        throw ValidationException(
          tr(
            'This cannot be removed: money was taken out of the goal after '
            'it.',
          ),
        );
      }
      await _db.goalsDao.deleteEntry(id);
    });
  }

  String _validated(String name, int target) {
    final clean = name.trim();
    if (clean.isEmpty) throw ValidationException(tr('Enter a name.'));
    if (clean.length > 60) {
      throw ValidationException(
        tr('The name must be {max} characters or fewer.', {'max': 60}),
      );
    }
    if (target <= 0) {
      throw ValidationException(tr('The target must be above zero.'));
    }
    return clean;
  }

  String _iconOrDefault(String icon) =>
      goalIcons.contains(icon) ? icon : defaultGoalIcon;
}

GoalWithSaved _toGoalWithSaved(GoalRowWithSaved row) => GoalWithSaved(
  goal: SavingsGoal(
    id: row.goal.id,
    name: row.goal.name,
    target: row.goal.target,
    targetDate: row.goal.targetDate?.toLocal(),
    icon: row.goal.icon,
    createdAt: row.goal.createdAt.toLocal(),
  ),
  saved: row.saved,
);

GoalEntry _toEntry(GoalEntryRow row) => GoalEntry(
  id: row.id,
  goalId: row.goalId,
  amount: row.amount,
  date: row.date.toLocal(),
  note: row.note,
);
