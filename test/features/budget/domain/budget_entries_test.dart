import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_entries_sheet.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

TransactionItem _item(
  int id,
  TransactionType type, {
  int? categoryId,
  bool adjustment = false,
}) => TransactionItem(
  id: id,
  type: type,
  amount: 1000,
  accountId: 1,
  accountName: 'Cash',
  date: DateTime(2026, 10, 5),
  note: '',
  createdAt: DateTime(2026, 10, 5),
  categoryId: categoryId,
  isAdjustment: adjustment,
);

void main() {
  test('only expenses of the category and those inside it count', () {
    final items = [
      _item(1, TransactionType.expense, categoryId: 10),
      _item(2, TransactionType.expense, categoryId: 11),
      _item(3, TransactionType.expense, categoryId: 20),
      _item(4, TransactionType.income, categoryId: 10),
      _item(5, TransactionType.expense, categoryId: 10, adjustment: true),
      _item(6, TransactionType.transfer),
    ];
    expect(budgetEntries(items, {10, 11}).map((e) => e.id), [1, 2]);
  });
}
