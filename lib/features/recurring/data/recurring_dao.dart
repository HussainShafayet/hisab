import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/recurring/data/recurring_table.dart';

part 'recurring_dao.g.dart';

@DriftAccessor(tables: [RecurringRules])
class RecurringDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringDaoMixin {
  RecurringDao(super.attachedDatabase);

  Stream<List<RecurringRuleRow>> watchAll() => (select(
    recurringRules,
  )..orderBy([(r) => OrderingTerm.asc(r.id)])).watch();

  Future<List<RecurringRuleRow>> getAll() =>
      (select(recurringRules)..orderBy([(r) => OrderingTerm.asc(r.id)])).get();

  Future<RecurringRuleRow?> getById(int id) =>
      (select(recurringRules)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<int> insertRule(RecurringRulesCompanion rule) =>
      into(recurringRules).insert(rule);

  Future<bool> updateRule(RecurringRuleRow rule) =>
      update(recurringRules).replace(rule);

  Future<int> deleteRule(int id) =>
      (delete(recurringRules)..where((r) => r.id.equals(id))).go();
}
