import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/default_accounts.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

import '../../helpers/test_database.dart';

int _countWithChildren(List<DefaultCategory> categories) =>
    categories.fold(0, (sum, c) => sum + 1 + c.children.length);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase(seedDefaults: true));
  tearDown(() => db.close());

  test(
    'creates the default accounts, active and counted in the total',
    () async {
      final accounts = await db.accountsDao.getAll();

      expect(accounts.map((a) => a.name), defaultAccounts.map((a) => a.name));
      expect(accounts.map((a) => a.type), defaultAccounts.map((a) => a.type));
      for (final account in accounts) {
        expect(account.openingBalance, 0);
        expect(account.includeInTotal, isTrue);
        expect(account.isArchived, isFalse);
      }
    },
  );

  test('creates every default category with the right type', () async {
    final expense = await db.categoriesDao.getAll(type: CategoryType.expense);
    final income = await db.categoriesDao.getAll(type: CategoryType.income);

    expect(expense, hasLength(_countWithChildren(defaultExpenseCategories)));
    expect(income, hasLength(_countWithChildren(defaultIncomeCategories)));
  });

  test('sub-categories point at a top-level parent of the same type', () async {
    final all = await db.categoriesDao.getAll();
    final byId = {for (final c in all) c.id: c};

    final subCategories = all.where((c) => c.parentId != null);
    expect(subCategories, isNotEmpty);
    for (final child in subCategories) {
      final parent = byId[child.parentId];
      expect(parent, isNotNull, reason: child.name);
      expect(parent!.parentId, isNull, reason: '${child.name} is nested twice');
      expect(parent.type, child.type, reason: child.name);
    }
  });

  test('top-level categories keep the order of the default list', () async {
    final expense = await db.categoriesDao.getAll(type: CategoryType.expense);
    final topLevel = expense.where((c) => c.parentId == null);

    expect(
      topLevel.map((c) => c.name),
      defaultExpenseCategories.map((c) => c.name),
    );
  });

  test('names are unique among siblings and icons are set', () async {
    final all = await db.categoriesDao.getAll();

    final keys = all.map((c) => '${c.type.name}/${c.parentId}/${c.name}');
    expect(keys.toSet(), hasLength(all.length));
    for (final category in all) {
      expect(category.icon, isNotEmpty, reason: category.name);
    }
  });
}
