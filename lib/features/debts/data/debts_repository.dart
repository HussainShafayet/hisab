import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/debts/data/debts_dao.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Loans: money lent to or borrowed from people, and what has been paid back.
///
/// When an account is given, its balance moves too, through a transaction
/// that is a correction (`is_adjustment`): lending is not spending, so
/// reports and budgets do not count it, but the account's balance does.
class DebtsRepository {
  DebtsRepository(this._db);

  final AppDatabase _db;

  static const maxPersonLength = 60;
  static const maxNoteLength = 500;

  /// Every debt with how much was paid, newest first. Emits again when a debt
  /// or a payment changes.
  Stream<List<DebtItem>> watchDebts() => _db.debtsDao.watchAllWithPaid().map(
    (rows) => [for (final r in rows) _toItem(r)],
  );

  Stream<DebtItem?> watchDebt(int id) => watchDebts().map(
    (items) => items.where((i) => i.debt.id == id).firstOrNull,
  );

  Future<DebtItem?> getDebt(int id) async {
    final row = await _db.debtsDao.getWithPaid(id);
    return row == null ? null : _toItem(row);
  }

  Stream<List<DebtPayment>> watchPayments(int debtId) => _db.debtsDao
      .watchPayments(debtId)
      .map((rows) => [for (final r in rows) _toPayment(r)]);

  /// The names already used, most recent first, for one-tap suggestions.
  Future<List<String>> knownPeople() async {
    final all = await _db.debtsDao.getAllDebts();
    final seen = <String>{};
    return [
      for (final debt in all.reversed)
        if (seen.add(debt.person.toLowerCase())) debt.person,
    ];
  }

  /// Saves a new debt and returns its id. With [accountId], the balance of
  /// that account moves by [amount] on [openedOn].
  Future<int> createDebt({
    required String person,
    required DebtDirection direction,
    required int amount,
    required DateTime openedOn,
    DateTime? dueOn,
    String note = '',
    int? accountId,
  }) {
    return _db.transaction(() async {
      final name = _validatedPerson(person);
      if (amount <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      _validateNote(note);
      if (dueOn != null && dateOnly(dueOn).isBefore(dateOnly(openedOn))) {
        throw ValidationException(
          tr('The due day cannot be before the day it was given.'),
        );
      }
      await _requireUsableAccount(accountId);

      final transactionId = accountId == null
          ? null
          : await _moveBalance(
              accountId: accountId,
              // Lending sends money out of the account; borrowing brings it in.
              type: direction == DebtDirection.lent
                  ? TransactionType.expense
                  : TransactionType.income,
              amount: amount,
              date: openedOn,
              note: direction == DebtDirection.lent
                  ? 'Lent to $name'
                  : 'Borrowed from $name',
            );
      return _db.debtsDao.insertDebt(
        DebtsCompanion.insert(
          person: name,
          direction: direction,
          amount: amount,
          openedOn: openedOn,
          dueOn: Value(dueOn),
          note: Value(note.trim()),
          accountId: Value(accountId),
          transactionId: Value(transactionId),
        ),
      );
    });
  }

  /// Changes a debt. Everything can change, with two limits: the amount
  /// cannot go below what is paid already, and the direction cannot change
  /// once something is paid (the payments went the other way).
  ///
  /// The balance change the debt made is made again for the new values: the
  /// old one is taken back and, with an [accountId], a new one is made. Payments
  /// keep their own balance changes.
  Future<void> updateDebt(
    int id, {
    required String person,
    required DebtDirection direction,
    required int amount,
    required DateTime openedOn,
    required DateTime? dueOn,
    required String note,
    required int? accountId,
  }) {
    return _db.transaction(() async {
      final debt = await _requireDebt(id);
      final paid = (await getDebt(id))!.paid;
      final name = _validatedPerson(person);
      if (amount <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      if (amount < paid) {
        throw ValidationException(
          tr('The amount cannot be less than the {paid} already paid.', {
            'paid': formatPoisha(paid),
          }),
        );
      }
      if (direction != debt.direction && paid > 0) {
        throw ValidationException(
          tr('The kind of loan cannot change once something is paid.'),
        );
      }
      _validateNote(note);
      if (dueOn != null && dateOnly(dueOn).isBefore(dateOnly(openedOn))) {
        throw ValidationException(
          tr('The due day cannot be before the day it was given.'),
        );
      }
      if (accountId != debt.accountId) await _requireUsableAccount(accountId);

      var transactionId = debt.transactionId;
      final changesBalance =
          name != debt.person ||
          direction != debt.direction ||
          amount != debt.amount ||
          accountId != debt.accountId ||
          !openedOn.isAtSameMomentAs(debt.openedOn);
      if (changesBalance) {
        // A transaction the person deleted by hand stays deleted, unless a
        // different account is chosen now.
        final remake =
            accountId != null &&
            (transactionId != null || accountId != debt.accountId);
        await _deleteTransaction(transactionId);
        transactionId = remake
            ? await _moveBalance(
                accountId: accountId,
                type: direction == DebtDirection.lent
                    ? TransactionType.expense
                    : TransactionType.income,
                amount: amount,
                date: openedOn,
                note: direction == DebtDirection.lent
                    ? 'Lent to $name'
                    : 'Borrowed from $name',
              )
            : null;
      }
      await _db.debtsDao.updateDebt(
        debt.copyWith(
          person: name,
          direction: direction,
          amount: amount,
          openedOn: openedOn,
          dueOn: Value(dueOn),
          note: note.trim(),
          accountId: Value(accountId),
          transactionId: Value(transactionId),
        ),
      );
    });
  }

  /// Records [amount] paid back on [paidOn] and returns the payment's id.
  /// It cannot be more than what is left. With [accountId], that account's
  /// balance moves too (money comes in for a loan I gave, goes out for one I
  /// took).
  Future<int> addPayment(
    int debtId, {
    required int amount,
    required DateTime paidOn,
    String note = '',
    int? accountId,
  }) {
    return _db.transaction(() async {
      final item = await getDebt(debtId);
      if (item == null) throw ValidationException(tr('Loan not found.'));
      if (amount <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      if (amount > item.remaining) {
        throw ValidationException(tr('That is more than what is left to pay.'));
      }
      _validateNote(note);
      await _requireUsableAccount(accountId);

      final lent = item.debt.direction == DebtDirection.lent;
      final transactionId = accountId == null
          ? null
          : await _moveBalance(
              accountId: accountId,
              type: lent ? TransactionType.income : TransactionType.expense,
              amount: amount,
              date: paidOn,
              note: lent
                  ? 'Received from ${item.debt.person}'
                  : 'Paid to ${item.debt.person}',
            );
      return _db.debtsDao.insertPayment(
        DebtPaymentsCompanion.insert(
          debtId: debtId,
          amount: amount,
          paidOn: paidOn,
          note: Value(note.trim()),
          accountId: Value(accountId),
          transactionId: Value(transactionId),
        ),
      );
    });
  }

  /// Sets what [person] owes me off against what I owe them: the same amount
  /// is paid on the loans going each way, so only the difference is left. No
  /// account balance changes. Returns the ids of the payments made, so they
  /// can be taken back with [deletePayments].
  Future<List<int>> setOff(String person, {required DateTime on}) {
    return _db.transaction(() async {
      final key = personKey(person);
      final items = [
        for (final row in await _db.debtsDao.getAllWithPaid())
          if (personKey(row.debt.person) == key) _toItem(row),
      ];
      final grouped = items.isEmpty ? null : groupByPerson(items, on).single;
      final steps = grouped == null
          ? const <SetOffStep>[]
          : planSetOff(grouped);
      if (grouped == null || steps.isEmpty) {
        throw ValidationException(tr('There is nothing to set off.'));
      }
      final name = grouped.name;
      return [
        for (final step in steps)
          await addPayment(
            step.debtId,
            amount: step.amount,
            paidOn: on,
            note: 'Set off with $name',
          ),
      ];
    });
  }

  /// Takes several payments back at once (see [setOff]).
  Future<void> deletePayments(Iterable<int> ids) {
    return _db.transaction(() async {
      for (final id in ids) {
        final payment = await _db.debtsDao.getPayment(id);
        if (payment == null) continue;
        await _db.debtsDao.deletePayment(id);
        await _deleteTransaction(payment.transactionId);
      }
    });
  }

  /// Takes a payment back, and the balance change it made.
  Future<void> deletePayment(int id) {
    return _db.transaction(() async {
      final payment = await _db.debtsDao.getPayment(id);
      if (payment == null) {
        throw ValidationException(tr('Payment not found.'));
      }
      await _db.debtsDao.deletePayment(id);
      await _deleteTransaction(payment.transactionId);
    });
  }

  /// Deletes the debt, its payments and every balance change they made.
  Future<void> deleteDebt(int id) {
    return _db.transaction(() async {
      final debt = await _requireDebt(id);
      final payments = await _db.debtsDao.getPayments(id);
      await _db.debtsDao.deleteDebt(id);
      for (final payment in payments) {
        await _deleteTransaction(payment.transactionId);
      }
      await _deleteTransaction(debt.transactionId);
    });
  }

  Future<int> _moveBalance({
    required int accountId,
    required TransactionType type,
    required int amount,
    required DateTime date,
    required String note,
  }) async {
    final categoryId = await _db.categoriesDao.findOrCreateTopLevel(
      loanCategoryName,
      type.categoryType!,
      icon: 'wallet',
      color: 0xFF607D8B,
    );
    return _db.transactionsDao.insertTransaction(
      TransactionsCompanion.insert(
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: Value(categoryId),
        date: date,
        note: Value(note),
        isAdjustment: const Value(true),
      ),
    );
  }

  Future<void> _deleteTransaction(int? id) async {
    if (id != null) await _db.transactionsDao.deleteTransaction(id);
  }

  Future<DebtRow> _requireDebt(int id) async {
    final row = await _db.debtsDao.getDebt(id);
    if (row == null) throw ValidationException(tr('Loan not found.'));
    return row;
  }

  String _validatedPerson(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw ValidationException(tr('Name is required.'));
    if (name.length > maxPersonLength) {
      throw ValidationException(
        tr('Name must be {max} characters or fewer.', {'max': maxPersonLength}),
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

  DebtItem _toItem(DebtWithPaid row) =>
      DebtItem(debt: _toDebt(row.debt), paid: row.paid);

  Debt _toDebt(DebtRow row) => Debt(
    id: row.id,
    person: row.person,
    direction: row.direction,
    amount: row.amount,
    openedOn: row.openedOn.toLocal(),
    dueOn: row.dueOn?.toLocal(),
    note: row.note,
    accountId: row.accountId,
  );

  DebtPayment _toPayment(DebtPaymentRow row) => DebtPayment(
    id: row.id,
    debtId: row.debtId,
    amount: row.amount,
    paidOn: row.paidOn.toLocal(),
    note: row.note,
    accountId: row.accountId,
  );
}
