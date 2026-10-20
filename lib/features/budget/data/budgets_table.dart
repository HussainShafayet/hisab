import 'package:drift/drift.dart';
import 'package:hishab/features/categories/data/categories_table.dart';

/// One row per (month, category). A null [categoryId] is the overall budget
/// for that month. Uniqueness is enforced by an index created in
/// `AppDatabase` because it needs an expression, which drift annotations
/// cannot express.
@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `YYYY-MM`.
  TextColumn get month => text().withLength(min: 7, max: 7)();

  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// In poisha, always positive.
  IntColumn get amount => integer()();

  /// This budget takes nothing from the months before and passes nothing on,
  /// even when carrying over is on.
  BoolColumn get noCarry => boolean().withDefault(const Constant(false))();

  // drift needs literal strings here.
  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
