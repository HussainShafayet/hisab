import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';

BudgetItem item(
  int id,
  String name, {
  required int limit,
  required int spent,
}) => BudgetItem(
  id: id,
  categoryId: id,
  categoryName: name,
  limit: limit,
  spent: spent,
);

void main() {
  test('sorts the most used up budget first', () {
    final sorted = sortBudgetItems([
      item(1, 'Rent', limit: 1000, spent: 500),
      item(2, 'Food', limit: 1000, spent: 1200),
      item(3, 'Fun', limit: 1000, spent: 900),
    ]);

    expect(sorted.map((i) => i.categoryName), ['Food', 'Fun', 'Rent']);
  });

  test('uses the percent, not the amount', () {
    final sorted = sortBudgetItems([
      item(1, 'Big', limit: 1000000, spent: 500000), // 50%
      item(2, 'Small', limit: 100, spent: 90), // 90%
    ]);

    expect(sorted.first.categoryName, 'Small');
  });

  test('breaks ties by name, ignoring case', () {
    final sorted = sortBudgetItems([
      item(1, 'transport', limit: 100, spent: 50),
      item(2, 'Food', limit: 100, spent: 50),
      item(3, 'Bills', limit: 100, spent: 50),
    ]);

    expect(sorted.map((i) => i.categoryName), ['Bills', 'Food', 'transport']);
  });

  test('does not change the list it was given', () {
    final items = [
      item(1, 'A', limit: 100, spent: 10),
      item(2, 'B', limit: 100, spent: 90),
    ];
    sortBudgetItems(items);

    expect(items.first.categoryName, 'A');
  });

  test('a month budget is empty only without any budget', () {
    final month = DateTime(2026, 10);
    expect(
      MonthBudget(month: month, overall: null, categories: const []).isEmpty,
      isTrue,
    );
    expect(
      MonthBudget(
        month: month,
        overall: const BudgetItem(id: 1, limit: 100, spent: 0),
        categories: const [],
      ).isEmpty,
      isFalse,
    );
  });
}
