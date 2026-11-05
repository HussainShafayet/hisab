import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/search/domain/search_results.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

var _next = 1;

TransactionItem tx(
  String note, {
  int amount = 5000,
  int day = 5,
  bool adjustment = false,
}) => TransactionItem(
  id: _next++,
  type: TransactionType.expense,
  amount: amount,
  accountId: 1,
  accountName: 'Cash',
  date: DateTime(2026, 10, day),
  note: note,
  createdAt: DateTime(2026, 10, day),
  isAdjustment: adjustment,
);

Category category(int id, String name, [int? parent]) => Category(
  id: id,
  name: name,
  type: CategoryType.expense,
  parentId: parent,
  icon: 'category',
  color: 0xFF000000,
  isArchived: false,
  sortOrder: 0,
);

AccountWithBalance account(int id, String name) => AccountWithBalance(
  account: Account(
    id: id,
    name: name,
    type: AccountType.cash,
    openingBalance: 0,
    includeInTotal: true,
    isArchived: false,
  ),
  balance: 0,
);

DebtItem loan(int id, String person, {String note = ''}) => DebtItem(
  debt: Debt(
    id: id,
    person: person,
    direction: DebtDirection.lent,
    amount: 1000,
    openedOn: DateTime(2026, 9, 1),
    note: note,
  ),
  paid: 0,
);

SearchResults find(String query, {List<TransactionItem>? txs}) => searchAll(
  query,
  transactions: txs ?? [tx('Lunch with Rahim'), tx('Rickshaw')],
  accounts: [account(1, 'bKash'), account(2, 'Cash')],
  categories: [category(1, 'Food'), category(2, 'Fish', 1)],
  loans: [
    loan(1, 'Rahim'),
    loan(2, 'Karim', note: 'for the shop'),
  ],
);

void main() {
  test('finds across transactions, accounts, categories and loans', () {
    final result = find('rahim');
    expect(result.transactions.map((t) => t.note), ['Lunch with Rahim']);
    expect(result.loans.map((l) => l.debt.person), ['Rahim']);
    expect(result.accounts, isEmpty);
    expect(result.categories, isEmpty);

    final fish = find('food');
    expect(fish.categories.map((c) => c.name), ['Food', 'Fish']);
    expect(find('bkash').accounts.single.account.name, 'bKash');
    expect(find('shop').loans.single.debt.person, 'Karim');
  });

  test('a short query finds nothing', () {
    expect(find('r').isEmpty, isTrue);
    expect(find('  ').isEmpty, isTrue);
  });

  test('the newest transactions come first and balance fixes never match', () {
    final result = find(
      'tea',
      txs: [
        tx('tea old', day: 1),
        tx('tea new', day: 9),
        tx('tea fix', day: 8, adjustment: true),
      ],
    );
    expect(result.transactions.map((t) => t.note), ['tea new', 'tea old']);
  });

  test('lists a few and says how many more there are', () {
    final result = find(
      'tea',
      txs: [for (var i = 0; i < 25; i++) tx('tea $i', day: 1 + i % 20)],
    );
    expect(result.transactions, hasLength(searchTransactionLimit));
    expect(result.moreTransactions, 5);
  });

  test('nothing found is empty', () {
    expect(find('zzzz').isEmpty, isTrue);
  });
}
