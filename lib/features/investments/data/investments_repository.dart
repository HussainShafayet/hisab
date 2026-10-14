import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/investments/data/investments_dao.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Everything the UI needs for investments: reading them with their sums, and
/// making, changing and deleting them and their lines, with the rules checked
/// in one place. When a line names an account, that account's balance moves
/// too: money put in and taken back through a correction (not spending, not
/// income), profit as income.
class InvestmentsRepository {
  InvestmentsRepository(this._db);

  final AppDatabase _db;

  static const maxNameLength = 60;
  static const maxNoteLength = 200;

  /// Every investment, oldest first, with what went in, came as profit and was
  /// taken back.
  Stream<List<InvestmentItem>> watchInvestments() => _db.investmentsDao
      .watchWithSums()
      .map((rows) => rows.map(_toItem).toList());

  Future<InvestmentItem?> getInvestment(int id) async {
    final row = await _db.investmentsDao.getWithSums(id);
    return row == null ? null : _toItem(row);
  }

  /// The lines of investment [investmentId], newest first.
  Stream<List<InvestmentEntry>> watchEntries(int investmentId) => _db
      .investmentsDao
      .watchEntries(investmentId)
      .map((rows) => rows.map(_toEntry).toList());

  /// Returns the new investment's id.
  Future<int> createInvestment({
    required String name,
    String note = '',
    required DateTime startedOn,
  }) async {
    final clean = _validatedName(name);
    _validateNote(note);
    return _db.investmentsDao.insertInvestment(
      InvestmentsCompanion.insert(
        name: clean,
        note: Value(note.trim()),
        startedOn: dateOnly(startedOn),
      ),
    );
  }

  Future<void> updateInvestment(
    int id, {
    required String name,
    String note = '',
    required DateTime startedOn,
  }) async {
    final current = await _requireInvestment(id);
    final clean = _validatedName(name);
    _validateNote(note);
    await _db.investmentsDao.updateInvestment(
      current.copyWith(
        name: clean,
        note: note.trim(),
        startedOn: dateOnly(startedOn),
      ),
    );
  }

  /// Sets what the money still in the investment is worth now. Null clears it,
  /// so the money is taken to be worth what it cost again.
  Future<void> setCurrentValue(int id, int? value) async {
    final current = await _requireInvestment(id);
    if (value != null && value < 0) {
      throw ValidationException(tr('The value cannot be negative.'));
    }
    await _db.investmentsDao.updateInvestment(
      current.copyWith(currentValue: Value(value)),
    );
  }

  /// Closes the investment (it is over; what was not taken back is lost) or
  /// opens it again.
  Future<void> setClosed(int id, {required bool closed}) async {
    final current = await _requireInvestment(id);
    await _db.investmentsDao.updateInvestment(
      current.copyWith(isClosed: closed),
    );
  }

  /// Deletes the investment, its lines and every balance change they made.
  Future<void> deleteInvestment(int id) {
    return _db.transaction(() async {
      await _requireInvestment(id);
      final entries = await _db.investmentsDao.getEntries(id);
      await _db.investmentsDao.deleteInvestment(id);
      for (final entry in entries) {
        await _deleteTransaction(entry.transactionId);
      }
    });
  }

  /// Adds a line and returns its id. Money cannot be taken back beyond what
  /// is still in the investment: the rest is profit. With an [accountId],
  /// that account's balance moves too.
  Future<int> addEntry(
    int investmentId, {
    required InvestmentEntryKind kind,
    required int amount,
    required DateTime date,
    String note = '',
    int? accountId,
  }) {
    return _db.transaction(() async {
      final item = await getInvestment(investmentId);
      if (item == null) {
        throw ValidationException(tr('Investment not found.'));
      }
      if (amount <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      _validateNote(note);
      if (kind == InvestmentEntryKind.putIn && item.investment.isClosed) {
        throw ValidationException(
          tr('This investment is closed. Open it again to put money in.'),
        );
      }
      if (kind == InvestmentEntryKind.takeBack && amount > item.stillIn) {
        throw ValidationException(
          item.stillIn == 0
              ? tr(
                  'No money is left in it to take back. Money above what you '
                  'put in is profit: record it as profit.',
                )
              : tr(
                  'Only {amount} of what you put in is still there. Money '
                  'above that is profit: record it as profit.',
                  {'amount': formatPoisha(item.stillIn)},
                ),
        );
      }
      await _requireUsableAccount(accountId);

      final transactionId = accountId == null
          ? null
          : await _moveBalance(
              accountId: accountId,
              kind: kind,
              amount: amount,
              date: date,
              name: item.investment.name,
            );
      return _db.investmentsDao.insertEntry(
        InvestmentEntriesCompanion.insert(
          investmentId: investmentId,
          kind: kind,
          amount: amount,
          date: date,
          note: Value(note.trim()),
          accountId: Value(accountId),
          transactionId: Value(transactionId),
        ),
      );
    });
  }

  /// Deletes a line and the balance change it made.
  Future<void> deleteEntry(int id) {
    return _db.transaction(() async {
      final entry = await _db.investmentsDao.getEntry(id);
      if (entry == null) {
        throw ValidationException(tr('That line was not found.'));
      }
      await _db.investmentsDao.deleteEntry(id);
      await _deleteTransaction(entry.transactionId);
    });
  }

  Future<int> _moveBalance({
    required int accountId,
    required InvestmentEntryKind kind,
    required int amount,
    required DateTime date,
    required String name,
  }) async {
    final isProfit = kind == InvestmentEntryKind.profit;
    // Money put in leaves the account; profit and money taken back arrive.
    final type = kind == InvestmentEntryKind.putIn
        ? TransactionType.expense
        : TransactionType.income;
    final categoryId = await _db.categoriesDao.findOrCreateTopLevel(
      isProfit ? investmentProfitCategoryName : investmentCategoryName,
      type.categoryType!,
      icon: 'trending_up',
      color: isProfit ? 0xFF43A047 : 0xFF00897B,
    );
    return _db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: Value(categoryId),
        date: date,
        note: Value(name),
        // Profit is income. Money in and out is only a move of your own money.
        isAdjustment: Value(!isProfit),
      ),
    );
  }

  Future<void> _deleteTransaction(int? id) async {
    if (id != null) await _db.transactionsDao.deleteTransaction(id);
  }

  Future<InvestmentRow> _requireInvestment(int id) async {
    final row = await _db.investmentsDao.getInvestment(id);
    if (row == null) throw ValidationException(tr('Investment not found.'));
    return row;
  }

  Future<void> _requireUsableAccount(int? id) async {
    if (id == null) return;
    final account = await _db.accountsDao.getById(id);
    if (account == null) {
      throw ValidationException(tr('Account not found.'));
    }
    if (account.isArchived) {
      throw ValidationException(
        tr('The account "{name}" is archived.', {'name': account.name}),
      );
    }
  }

  String _validatedName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw ValidationException(tr('Enter a name.'));
    if (name.length > maxNameLength) {
      throw ValidationException(
        tr('The name must be {max} characters or fewer.', {
          'max': maxNameLength,
        }),
      );
    }
    return name;
  }

  void _validateNote(String note) {
    if (note.trim().length > maxNoteLength) {
      throw ValidationException(
        tr('The note must be {max} characters or fewer.', {
          'max': maxNoteLength,
        }),
      );
    }
  }

  InvestmentItem _toItem(InvestmentRowWithSums row) => InvestmentItem(
    investment: Investment(
      id: row.investment.id,
      name: row.investment.name,
      note: row.investment.note,
      startedOn: row.investment.startedOn.toLocal(),
      isClosed: row.investment.isClosed,
      currentValue: row.investment.currentValue,
    ),
    putIn: row.putIn,
    profit: row.profit,
    takenBack: row.takenBack,
  );

  InvestmentEntry _toEntry(InvestmentEntryRow row) => InvestmentEntry(
    id: row.id,
    investmentId: row.investmentId,
    kind: row.kind,
    amount: row.amount,
    date: row.date.toLocal(),
    note: row.note,
    accountId: row.accountId,
  );
}
