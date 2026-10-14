import 'package:drift/drift.dart';

/// Things being saved up for. The money is set aside in the app only: it does
/// not move out of any account, so balances and reports are not touched.
@DataClassName('SavingsGoalRow')
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// What is being saved, in poisha.
  IntColumn get target => integer()();

  /// The day the goal should be reached by (midnight, local), if there is one.
  DateTimeColumn get targetDate => dateTime().nullable()();

  /// A key of the icons a goal can have (see `goalIcons`).
  TextColumn get icon => text().withDefault(const Constant('target'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (target > 0)'];
}

/// Money put into a goal (above zero) or taken out of it (below zero).
@DataClassName('GoalEntryRow')
@TableIndex(name: 'idx_goal_entries_goal_id', columns: {#goalId})
class GoalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get goalId =>
      integer().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();

  /// In poisha. Not zero.
  IntColumn get amount => integer()();

  DateTimeColumn get date => dateTime()();

  TextColumn get note => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount <> 0)'];
}
