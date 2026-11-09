import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/data/paid_for_me.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final day = DateTime(2026, 10, 9, 20);

void main() {
  late AppDatabase db;
  late PaidForMe paidForMe;
  late int cash;
  late int food;

  setUp(() async {
    db = createTestDatabase();
    paidForMe = PaidForMe(db);
    cash = await insertTestAccount(db, name: 'Cash');
    food = await insertTestCategory(db, name: 'Food');
  });
  tearDown(() => db.close());

  Future<int> balance() async {
    final accounts = await AccountsRepository(db).watchAccounts().first;
    return accounts.firstWhere((a) => a.account.id == cash).balance;
  }

  Future<int> record({String person = 'Rahim', int? category}) =>
      paidForMe.record(
        person: person,
        amount: 50000,
        accountId: cash,
        categoryId: category ?? food,
        date: day,
        note: 'Lunch',
      );

  test('makes a loan I owe and leaves the balance alone', () async {
    final before = await balance();

    final id = await record();

    final item = (await DebtsRepository(db).getDebt(id))!;
    expect(item.debt.direction, DebtDirection.borrowed);
    expect(item.debt.person, 'Rahim');
    expect(item.debt.amount, 50000);
    expect(item.paid, 0);
    expect(await balance(), before);
  });

  test('counts as one expense in the category', () async {
    await record();

    final rows = await db.select(db.transactions).get();
    final spending = rows.where((t) => !t.isAdjustment).toList();
    expect(spending, hasLength(1));
    expect(spending.single.type, TransactionType.expense);
    expect(spending.single.amount, 50000);
    expect(spending.single.categoryId, food);
    expect(spending.single.note, 'Lunch');
    // The other side only balances the account: it is not income.
    final corrections = rows.where((t) => t.isAdjustment).toList();
    expect(corrections, hasLength(1));
    expect(corrections.single.type, TransactionType.income);
  });

  test('says who paid when there is no note', () async {
    await paidForMe.record(
      person: 'Rahim',
      amount: 50000,
      accountId: cash,
      categoryId: food,
      date: day,
    );

    final rows = await db.select(db.transactions).get();
    expect(rows.singleWhere((t) => !t.isAdjustment).note, 'Paid by Rahim');
  });

  test('saves nothing when the name is missing', () async {
    await expectLater(record(person: ' '), throwsA(isA<ValidationException>()));

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.debts).get(), isEmpty);
  });

  test('saves nothing when the expense cannot be made', () async {
    await expectLater(record(category: 99999), throwsA(anything));

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.debts).get(), isEmpty);
  });
}
