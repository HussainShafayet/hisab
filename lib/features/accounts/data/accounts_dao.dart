import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/accounts/data/default_accounts.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'accounts_dao.g.dart';

/// An account row plus the money that moved through it.
typedef AccountWithFlows = ({AccountRow account, AccountFlows flows});

/// Accounts are never deleted, only archived, so there is deliberately no
/// delete method here.
@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.attachedDatabase);

  SimpleSelectStatement<$AccountsTable, AccountRow> _selectAll({
    required bool includeArchived,
  }) {
    final query = select(accounts);
    if (!includeArchived) {
      query.where((a) => a.isArchived.equals(false));
    }
    return query..orderBy([(a) => OrderingTerm.asc(a.id)]);
  }

  Stream<List<AccountRow>> watchAll({bool includeArchived = false}) =>
      _selectAll(includeArchived: includeArchived).watch();

  Future<List<AccountRow>> getAll({bool includeArchived = false}) =>
      _selectAll(includeArchived: includeArchived).get();

  /// Accounts with their income, expense and transfer sums, calculated by
  /// SQLite in one query. Emits again whenever accounts or transactions change.
  Stream<List<AccountWithFlows>> watchAllWithFlows({
    bool includeArchived = false,
  }) => _selectWithFlows(includeArchived: includeArchived).watch();

  Future<List<AccountWithFlows>> getAllWithFlows({
    bool includeArchived = false,
  }) => _selectWithFlows(includeArchived: includeArchived).get();

  Future<AccountWithFlows?> getWithFlows(int id) =>
      _selectWithFlows(includeArchived: true, id: id).getSingleOrNull();

  Selectable<AccountWithFlows> _selectWithFlows({
    required bool includeArchived,
    int? id,
  }) {
    // The type names come from our own enum, never from user input.
    String sum(String condition) =>
        '(SELECT COALESCE(SUM(t.amount), 0) FROM transactions t '
        'WHERE $condition)';
    final income = TransactionType.income.name;
    final expense = TransactionType.expense.name;
    final transfer = TransactionType.transfer.name;
    final filters = [
      if (!includeArchived) 'a.is_archived = 0',
      if (id != null) 'a.id = ?',
    ];

    return customSelect(
      'SELECT a.*, '
      "${sum("t.account_id = a.id AND t.type = '$income'")} AS income, "
      "${sum("t.account_id = a.id AND t.type = '$expense'")} AS expense, "
      "${sum("t.account_id = a.id AND t.type = '$transfer'")} AS transfer_out, "
      "${sum("t.to_account_id = a.id AND t.type = '$transfer'")} AS transfer_in "
      'FROM accounts a '
      '${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')} '}'
      'ORDER BY a.id',
      variables: [if (id != null) Variable.withInt(id)],
      readsFrom: {accounts, attachedDatabase.transactions},
    ).map(
      (row) => (
        account: accounts.map(row.data),
        flows: AccountFlows(
          income: row.read<int>('income'),
          expense: row.read<int>('expense'),
          transferOut: row.read<int>('transfer_out'),
          transferIn: row.read<int>('transfer_in'),
        ),
      ),
    );
  }

  Future<AccountRow?> getById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Returns the new id.
  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  /// Replaces the whole row. Returns false if the id does not exist.
  Future<bool> updateAccount(AccountRow account) =>
      update(accounts).replace(account);

  Future<void> setArchived(int id, {required bool archived}) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(isArchived: Value(archived)),
      );

  Future<void> insertDefaults() => batch((b) {
    b.insertAll(accounts, [
      for (final account in defaultAccounts)
        AccountsCompanion.insert(name: account.name, type: account.type),
    ]);
  });
}
