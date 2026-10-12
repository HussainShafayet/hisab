import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/data/account_mapper.dart';
import 'package:hishab/features/accounts/data/accounts_dao.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Everything the UI needs to know about accounts. Validates input, turns
/// database rows into domain models and keeps the rules in one place.
class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  static const maxNameLength = 60;

  /// Accounts with their current balance, oldest first. Emits again when an
  /// account or any transaction changes.
  Stream<List<AccountWithBalance>> watchAccounts({
    bool includeArchived = false,
  }) {
    return _db.accountsDao
        .watchAllWithFlows(includeArchived: includeArchived)
        .map((rows) => rows.map(_toAccountWithBalance).toList());
  }

  /// The balance of all accounts that count in the total: active ones that
  /// are not left out with "include in total". See [calculateTotalBalance].
  Future<int> totalBalance() async {
    final rows = await _db.accountsDao.getAllWithFlows(includeArchived: true);
    return calculateTotalBalance(rows.map(_toAccountWithBalance));
  }

  Future<Account?> getAccount(int id) async {
    final row = await _db.accountsDao.getById(id);
    return row?.toDomain();
  }

  /// Returns the new account's id.
  Future<int> createAccount({
    required String name,
    required AccountType type,
    int openingBalance = 0,
    bool includeInTotal = true,
  }) async {
    final cleanName = await _validatedName(name);
    return _db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: cleanName,
        type: type,
        openingBalance: Value(openingBalance),
        includeInTotal: Value(includeInTotal),
      ),
    );
  }

  Future<void> updateAccount(
    int id, {
    required String name,
    required AccountType type,
    required int openingBalance,
    required bool includeInTotal,
  }) async {
    final current = await _requireRow(id);
    final cleanName = await _validatedName(name, excludeId: id);
    await _db.accountsDao.updateAccount(
      current.copyWith(
        name: cleanName,
        type: type,
        openingBalance: openingBalance,
        includeInTotal: includeInTotal,
      ),
    );
  }

  /// Hides the account from lists. Its transactions are untouched.
  Future<void> archiveAccount(int id) async {
    await _requireRow(id);
    await _db.accountsDao.setArchived(id, archived: true);
  }

  Future<void> restoreAccount(int id) async {
    await _requireRow(id);
    await _db.accountsDao.setArchived(id, archived: false);
  }

  /// Records an income or expense transaction so the account's balance becomes
  /// [targetBalance]. Returns what was recorded, or null if the balance
  /// already matched.
  Future<BalanceAdjustment?> adjustBalance(
    int accountId, {
    required int targetBalance,
  }) {
    return _db.transaction(() async {
      final row = await _db.accountsDao.getWithFlows(accountId);
      if (row == null) throw const ValidationException('Account not found.');

      final adjustment = calculateBalanceAdjustment(
        current: _balanceOf(row),
        target: targetBalance,
      );
      if (adjustment == null) return null;

      final categoryId = await _balanceAdjustmentCategoryId(
        adjustment.type == TransactionType.income
            ? CategoryType.income
            : CategoryType.expense,
      );
      await _db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: adjustment.type,
          amount: adjustment.amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          date: DateTime.now(),
          note: const Value(balanceAdjustmentNote),
          isAdjustment: const Value(true),
        ),
      );
      return adjustment;
    });
  }

  Future<int> _balanceAdjustmentCategoryId(CategoryType type) => _db
      .categoriesDao
      .findOrCreateTopLevel(balanceAdjustmentCategoryName, type, icon: 'tune');

  Future<AccountRow> _requireRow(int id) async {
    final row = await _db.accountsDao.getById(id);
    if (row == null) throw const ValidationException('Account not found.');
    return row;
  }

  /// Trims [raw] and checks it is a usable, unused name.
  Future<String> _validatedName(String raw, {int? excludeId}) async {
    final name = raw.trim();
    if (name.isEmpty) throw const ValidationException('Name is required.');
    if (name.length > maxNameLength) {
      throw const ValidationException(
        'Name must be $maxNameLength characters or fewer.',
      );
    }
    final all = await _db.accountsDao.getAll(includeArchived: true);
    for (final other in all) {
      if (other.id != excludeId &&
          other.name.toLowerCase() == name.toLowerCase()) {
        throw ValidationException(
          other.isArchived
              ? 'An archived account named "${other.name}" exists. '
                    'Restore it instead.'
              : 'An account named "${other.name}" already exists.',
        );
      }
    }
    return name;
  }

  int _balanceOf(AccountWithFlows row) => calculateAccountBalance(
    openingBalance: row.account.openingBalance,
    flows: row.flows,
  );

  AccountWithBalance _toAccountWithBalance(AccountWithFlows row) =>
      AccountWithBalance(
        account: row.account.toDomain(),
        balance: _balanceOf(row),
      );
}
