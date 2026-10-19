// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenges_dao.dart';

// ignore_for_file: type=lint
mixin _$ChallengesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ChallengesTable get challenges => attachedDatabase.challenges;
  ChallengesDaoManager get managers => ChallengesDaoManager(this);
}

class ChallengesDaoManager {
  final _$ChallengesDaoMixin _db;
  ChallengesDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ChallengesTableTableManager get challenges =>
      $$ChallengesTableTableManager(_db.attachedDatabase, _db.challenges);
}
