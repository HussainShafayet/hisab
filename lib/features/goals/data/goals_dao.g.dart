// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goals_dao.dart';

// ignore_for_file: type=lint
mixin _$GoalsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavingsGoalsTable get savingsGoals => attachedDatabase.savingsGoals;
  $GoalEntriesTable get goalEntries => attachedDatabase.goalEntries;
  GoalsDaoManager get managers => GoalsDaoManager(this);
}

class GoalsDaoManager {
  final _$GoalsDaoMixin _db;
  GoalsDaoManager(this._db);
  $$SavingsGoalsTableTableManager get savingsGoals =>
      $$SavingsGoalsTableTableManager(_db.attachedDatabase, _db.savingsGoals);
  $$GoalEntriesTableTableManager get goalEntries =>
      $$GoalEntriesTableTableManager(_db.attachedDatabase, _db.goalEntries);
}
