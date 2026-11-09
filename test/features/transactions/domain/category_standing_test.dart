import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/category_standing.dart';

Category cat(int id, String name, {int? parent}) => Category(
  id: id,
  name: name,
  type: CategoryType.expense,
  parentId: parent,
  icon: 'category',
  color: 0xFF000000,
  isArchived: false,
  sortOrder: id,
);

BudgetItem budget(
  int categoryId,
  String name, {
  int limit = 10000,
  int spent = 0,
}) => BudgetItem(
  id: categoryId,
  categoryId: categoryId,
  categoryName: name,
  limit: limit,
  spent: spent,
);

void main() {
  final byId = {
    1: cat(1, 'Food'),
    2: cat(2, 'Kacha bazar', parent: 1),
    3: cat(3, 'Fish', parent: 2),
    4: cat(4, 'Transport'),
  };

  group('budgetCovering', () {
    test('is the budget of the category itself', () {
      final found = budgetCovering(3, byId, [
        budget(3, 'Fish'),
        budget(1, 'Food'),
      ]);
      expect(found?.categoryName, 'Fish');
    });

    test('is the nearest budget above when the category has none', () {
      final found = budgetCovering(3, byId, [
        budget(1, 'Food'),
        budget(4, 'Transport'),
      ]);
      expect(found?.categoryName, 'Food');
    });

    test('is null when nothing above has one', () {
      expect(budgetCovering(3, byId, [budget(4, 'Transport')]), isNull);
    });

    test('ignores the overall budget (no category)', () {
      const overall = BudgetItem(id: 9, limit: 99999, spent: 0);
      expect(budgetCovering(3, byId, [overall]), isNull);
    });
  });

  group('standingLine', () {
    test('says what the month holds, and adds the entry', () {
      final line = standingLine(
        const CategoryStanding(total: 4200),
        entry: 500,
      );
      expect(line.now, 4200);
      expect(line.after, 4700);
      expect(line.hasEntry, isTrue);
      expect(line.budgetLeft, isNull);
    });

    test('has no entry while the amount is empty', () {
      final line = standingLine(const CategoryStanding(total: 4200), entry: 0);
      expect(line.hasEntry, isFalse);
      expect(line.after, line.now);
    });

    test('counts the budget left before and after the entry', () {
      final line = standingLine(
        CategoryStanding(
          total: 4000,
          budget: budget(1, 'Food', limit: 10000, spent: 4000),
        ),
        entry: 1500,
      );
      expect(line.budgetName, 'Food');
      expect(line.budgetLeft, 6000);
      expect(line.budgetLeftAfter, 4500);
    });

    test('goes negative when the entry passes the budget', () {
      final line = standingLine(
        CategoryStanding(
          total: 9000,
          budget: budget(1, 'Food', limit: 10000, spent: 9000),
        ),
        entry: 2500,
      );
      expect(line.budgetLeft, 1000);
      expect(line.budgetLeftAfter, -1500);
    });

    test('does not count an edited entry twice', () {
      // The entry of 1000 is already inside the 4000 and inside the budget.
      final line = standingLine(
        CategoryStanding(
          total: 4000,
          budget: budget(1, 'Food', limit: 10000, spent: 4000),
        ),
        entry: 1000,
        counted: 1000,
      );
      expect(line.now, 3000);
      expect(line.after, 4000);
      expect(line.budgetLeft, 7000);
      expect(line.budgetLeftAfter, 6000);
    });
  });
}
