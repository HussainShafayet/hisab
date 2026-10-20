import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/batch_rows.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

Account account(int id, String name) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: false,
);

Category category(
  int id,
  String name, {
  CategoryType type = CategoryType.expense,
}) => Category(
  id: id,
  name: name,
  type: type,
  parentId: null,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: id,
);

final options = AddTransactionOptions(
  accounts: [account(1, 'Cash'), account(2, 'bKash')],
  defaultAccountId: 1,
  expenseCategories: [category(10, 'Food'), category(13, 'Transport')],
  incomeCategories: [category(20, 'Salary', type: CategoryType.income)],
);

List<BatchDraft> read(String text, {int? account = 1}) =>
    draftsFromLines(text, options, defaultAccountId: account);

void main() {
  group('draftsFromLines', () {
    test('makes a row of each line', () {
      final drafts = read('transport 50\nfood 120 bkash\n+salary 30k');

      expect(drafts, hasLength(3));
      expect(drafts[0].type, TransactionType.expense);
      expect(drafts[0].amountText, '50');
      expect(drafts[0].categoryId, 13);
      expect(drafts[0].accountId, 1);
      expect(drafts[1].amountText, '120');
      expect(drafts[1].categoryId, 10);
      expect(drafts[1].accountId, 2);
      expect(drafts[2].type, TransactionType.income);
      expect(drafts[2].amountText, '30000');
      expect(drafts[2].categoryId, 20);
    });

    test('skips blank lines and copes with Windows line ends', () {
      final drafts = read('\n  \ntransport 50\r\n\r\nfood 120\n\n');

      expect(drafts.map((d) => d.amountText), ['50', '120']);
    });

    test('a line with no amount still makes a row, to be finished', () {
      final drafts = read('transport');

      expect(drafts.single.amountText, '');
      expect(drafts.single.categoryId, 13);
    });

    test('a line with only an amount has no category', () {
      final drafts = read('250');

      expect(drafts.single.amountText, '250');
      expect(drafts.single.categoryId, isNull);
    });

    test('the words that are left are the note', () {
      final drafts = read('transport ride to office 50');

      expect(drafts.single.note, 'Transport ride to office');
    });

    test('uses the account given when the line names none', () {
      expect(read('food 100', account: 2).single.accountId, 2);
      expect(read('food 100 cash', account: 2).single.accountId, 1);
      expect(read('food 100', account: null).single.accountId, isNull);
    });

    test('gives nothing for text with nothing in it', () {
      expect(read(''), isEmpty);
      expect(read('   \n \n'), isEmpty);
    });

    test('reads Bengali digits and amounts like 2k', () {
      final drafts = read('food ২৫০\nfood 2k');

      expect(drafts.map((d) => d.amountText), ['250', '2000']);
    });
  });
}
