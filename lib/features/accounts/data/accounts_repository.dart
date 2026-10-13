import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/data/account_mapper.dart';
import 'package:hishab/features/accounts/data/accounts_dao.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';
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

  /// The dollars on each credit card that has any, by account id. "This
  /// month" is `start <= date < end`.
  Stream<Map<int, CardDollars>> watchCardDollars(DateTime start, DateTime end) {
    final expense = TransactionType.expense.name;
    final income = TransactionType.income.name;
    final transfer = TransactionType.transfer.name;
    // The type names come from our own enum, never from user input. A
    // transfer counts for the card it goes into, the rest for their account.
    return _db
        .customSelect(
          'SELECT agg.*, (SELECT t2.amount * 1.0 / t2.usd_amount '
          "FROM transactions t2 WHERE t2.type = '$expense' "
          'AND t2.account_id = agg.card_id AND t2.usd_amount IS NOT NULL '
          'ORDER BY t2.date DESC, t2.id DESC LIMIT 1) AS last_rate '
          'FROM (SELECT '
          "CASE WHEN type = '$transfer' THEN to_account_id ELSE account_id END "
          'AS card_id, '
          "SUM(CASE WHEN type = '$expense' THEN usd_amount ELSE 0 END) "
          'AS spent, '
          "SUM(CASE WHEN type = '$income' THEN usd_amount ELSE 0 END) "
          'AS refunded, '
          "SUM(CASE WHEN type = '$transfer' THEN usd_amount ELSE 0 END) "
          'AS settled, '
          "SUM(CASE WHEN type = '$expense' AND date >= ? AND date < ? "
          'THEN usd_amount ELSE 0 END) AS month_spent '
          'FROM transactions WHERE usd_amount IS NOT NULL '
          'GROUP BY card_id) agg',
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {_db.transactions},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<int>('card_id'): CardDollars(
                spent: row.read<int>('spent'),
                refunded: row.read<int>('refunded'),
                settled: row.read<int>('settled'),
                spentThisMonth: row.read<int>('month_spent'),
                lastRate: row.readNullable<double>('last_rate'),
              ),
          },
        );
  }

  /// The balance of all accounts that count in the total: active ones that
  /// are not left out with "include in total". See [calculateTotalBalance].
  Future<int> totalBalance() async {
    final rows = await _db.accountsDao.getAllWithFlows(includeArchived: true);
    return calculateTotalBalance(rows.map(_toAccountWithBalance));
  }

  /// A one-off read of the accounts, without balances.
  Future<List<Account>> getAccounts({bool includeArchived = false}) async {
    final rows = await _db.accountsDao.getAll(includeArchived: includeArchived);
    return [for (final row in rows) row.toDomain()];
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
    int? creditLimit,
    int? usdLimit,
    int? billDueDay,
  }) async {
    final cleanName = await _validatedName(name);
    final card = _validatedCard(type, creditLimit, usdLimit, billDueDay);
    return _db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: cleanName,
        type: type,
        openingBalance: Value(openingBalance),
        includeInTotal: Value(includeInTotal),
        creditLimit: Value(card.limit),
        usdLimit: Value(card.usdLimit),
        billDueDay: Value(card.dueDay),
      ),
    );
  }

  Future<void> updateAccount(
    int id, {
    required String name,
    required AccountType type,
    required int openingBalance,
    required bool includeInTotal,
    int? creditLimit,
    int? usdLimit,
    int? billDueDay,
  }) async {
    final current = await _requireRow(id);
    final cleanName = await _validatedName(name, excludeId: id);
    final card = _validatedCard(type, creditLimit, usdLimit, billDueDay);
    await _db.accountsDao.updateAccount(
      current.copyWith(
        name: cleanName,
        type: type,
        openingBalance: openingBalance,
        includeInTotal: includeInTotal,
        creditLimit: Value(card.limit),
        usdLimit: Value(card.usdLimit),
        billDueDay: Value(card.dueDay),
      ),
    );
  }

  /// The limit and bill day to save: only a credit card has them, and they
  /// must make sense.
  ({int? limit, int? usdLimit, int? dueDay}) _validatedCard(
    AccountType type,
    int? creditLimit,
    int? usdLimit,
    int? billDueDay,
  ) {
    if (type != AccountType.creditCard) {
      return (limit: null, usdLimit: null, dueDay: null);
    }
    if (creditLimit != null && creditLimit <= 0) {
      throw ValidationException(tr('The credit limit must be above zero.'));
    }
    if (usdLimit != null && usdLimit <= 0) {
      throw ValidationException(tr('The dollar limit must be above zero.'));
    }
    if (billDueDay != null && (billDueDay < 1 || billDueDay > 31)) {
      throw ValidationException(tr('The bill day must be from 1 to 31.'));
    }
    return (limit: creditLimit, usdLimit: usdLimit, dueDay: billDueDay);
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
      if (row == null) throw ValidationException(tr('Account not found.'));

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
    if (row == null) throw ValidationException(tr('Account not found.'));
    return row;
  }

  /// Trims [raw] and checks it is a usable, unused name.
  Future<String> _validatedName(String raw, {int? excludeId}) async {
    final name = raw.trim();
    if (name.isEmpty) throw ValidationException(tr('Name is required.'));
    if (name.length > maxNameLength) {
      throw ValidationException(
        tr('Name must be {max} characters or fewer.', {'max': maxNameLength}),
      );
    }
    final all = await _db.accountsDao.getAll(includeArchived: true);
    for (final other in all) {
      if (other.id != excludeId &&
          other.name.toLowerCase() == name.toLowerCase()) {
        throw ValidationException(
          other.isArchived
              ? tr(
                  'An archived account named "{name}" exists. '
                  'Restore it instead.',
                  {'name': other.name},
                )
              : tr('An account named "{name}" already exists.', {
                  'name': other.name,
                }),
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
