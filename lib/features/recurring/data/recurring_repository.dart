import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Incomes and expenses that repeat: the rules, and turning their days into
/// transactions, either by itself or when the person says so.
class RecurringRepository {
  RecurringRepository(this._db) : _transactions = TransactionsRepository(_db);

  final AppDatabase _db;
  final TransactionsRepository _transactions;

  static const maxTitleLength = 60;

  Stream<List<RecurringRule>> watchRules() => _db.recurringDao.watchAll().map(
    (rows) => [for (final row in rows) _toRule(row)],
  );

  Future<List<RecurringRule>> getRules() async => [
    for (final row in await _db.recurringDao.getAll()) _toRule(row),
  ];

  Future<RecurringRule?> getRule(int id) async {
    final row = await _db.recurringDao.getById(id);
    return row == null ? null : _toRule(row);
  }

  /// Saves a new rule and returns its id. The first day it is due is
  /// [startDate].
  Future<int> createRule({
    required String title,
    required TransactionType type,
    required int amount,
    required int accountId,
    required int categoryId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    bool autoAdd = false,
    bool remind = true,
  }) {
    return _db.transaction(() async {
      final name = await _validate(
        title: title,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: categoryId,
        startDate: startDate,
        endDate: endDate,
      );
      final start = dateOnly(startDate);
      return _db.recurringDao.insertRule(
        RecurringRulesCompanion.insert(
          title: name,
          type: type,
          amount: amount,
          accountId: accountId,
          categoryId: categoryId,
          frequency: frequency,
          startDate: start,
          nextDue: start,
          endDate: Value(endDate == null ? null : dateOnly(endDate)),
          autoAdd: Value(autoAdd),
          remind: Value(remind),
        ),
      );
    });
  }

  /// Changes a rule. When the first day or how often it repeats changes, the
  /// days start again from the new first day; otherwise it carries on from the
  /// day it was waiting for.
  Future<void> updateRule(
    int id, {
    required String title,
    required TransactionType type,
    required int amount,
    required int accountId,
    required int categoryId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    required bool autoAdd,
    required bool remind,
  }) {
    return _db.transaction(() async {
      final row = await _requireRow(id);
      final name = await _validate(
        title: title,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: categoryId,
        startDate: startDate,
        endDate: endDate,
        // The account and category it already has may have been archived.
        existing: row,
      );
      final start = dateOnly(startDate);
      final restart = start != row.startDate || frequency != row.frequency;
      await _db.recurringDao.updateRule(
        row.copyWith(
          title: name,
          type: type,
          amount: amount,
          accountId: accountId,
          categoryId: categoryId,
          frequency: frequency,
          startDate: start,
          nextDue: restart ? start : row.nextDue,
          endDate: Value(endDate == null ? null : dateOnly(endDate)),
          autoAdd: autoAdd,
          remind: remind,
        ),
      );
    });
  }

  Future<void> setPaused(int id, {required bool paused}) async {
    final row = await _requireRow(id);
    await _db.recurringDao.updateRule(row.copyWith(isPaused: paused));
  }

  Future<void> deleteRule(int id) async {
    await _requireRow(id);
    await _db.recurringDao.deleteRule(id);
  }

  /// Adds the transaction for the day that is waiting (the oldest one due on
  /// or before [today]) and moves the rule on to the next day. [amount] is
  /// what to add when it differs from the rule's usual amount. Returns the new
  /// transaction's id.
  Future<int> addDue(int id, DateTime today, {int? amount}) {
    return _db.transaction(() async {
      final rule = _toRule(await _requireRow(id));
      final day = _waitingDay(rule, today);
      final value = amount ?? rule.amount;
      if (value <= 0) {
        throw ValidationException(tr('The amount must be above zero.'));
      }
      final transactionId = await _transactions.addTransaction(
        _transactionFor(rule, day, value, today),
      );
      await _moveOn(rule, day);
      return transactionId;
    });
  }

  /// Leaves out the day that is waiting: no transaction, the rule moves on.
  Future<void> skipDue(int id, DateTime today) {
    return _db.transaction(() async {
      final rule = _toRule(await _requireRow(id));
      await _moveOn(rule, _waitingDay(rule, today));
    });
  }

  /// Adds every day that is due on or before [today] for the rules that add
  /// themselves, catching up on days missed while the app was closed. A rule
  /// whose transaction cannot be saved (its account was archived, say) is
  /// left waiting. Returns how many transactions were added.
  Future<int> addAutomatic(DateTime today) async {
    var added = 0;
    for (final rule in await getRules()) {
      if (rule.isPaused || !rule.autoAdd) continue;
      var next = rule.nextDue;
      for (final day in dueDates(rule, today)) {
        try {
          await _transactions.addTransaction(
            _transactionFor(rule, day, rule.amount, today),
          );
        } on ValidationException {
          break;
        }
        added++;
        next = nextOccurrence(day, rule.frequency, rule.startDate);
      }
      if (next != rule.nextDue) {
        final row = await _requireRow(rule.id);
        await _db.recurringDao.updateRule(row.copyWith(nextDue: next));
      }
    }
    return added;
  }

  DateTime _waitingDay(RecurringRule rule, DateTime today) {
    if (rule.isPaused) {
      throw ValidationException(tr('This recurring item is paused.'));
    }
    final dates = dueDates(rule, today, limit: 1);
    if (dates.isEmpty) {
      throw ValidationException(tr('Nothing is due yet.'));
    }
    return dates.first;
  }

  Future<void> _moveOn(RecurringRule rule, DateTime day) async {
    final row = await _requireRow(rule.id);
    await _db.recurringDao.updateRule(
      row.copyWith(
        nextDue: nextOccurrence(day, rule.frequency, rule.startDate),
      ),
    );
  }

  TransactionInput _transactionFor(
    RecurringRule rule,
    DateTime day,
    int amount,
    DateTime now,
  ) => TransactionInput(
    type: rule.type,
    amount: amount,
    accountId: rule.accountId,
    categoryId: rule.categoryId,
    date: combineDayWithTime(day, now),
    note: rule.title,
  );

  Future<RecurringRuleRow> _requireRow(int id) async {
    final row = await _db.recurringDao.getById(id);
    if (row == null) {
      throw ValidationException(tr('Recurring item not found.'));
    }
    return row;
  }

  /// Checks a rule and returns its trimmed title.
  Future<String> _validate({
    required String title,
    required TransactionType type,
    required int amount,
    required int accountId,
    required int categoryId,
    required DateTime startDate,
    required DateTime? endDate,
    RecurringRuleRow? existing,
  }) async {
    final name = title.trim();
    if (name.isEmpty) throw ValidationException(tr('Name is required.'));
    if (name.length > maxTitleLength) {
      throw ValidationException(
        tr('Name must be {max} characters or fewer.', {'max': maxTitleLength}),
      );
    }
    if (type == TransactionType.transfer) {
      throw ValidationException(
        tr('A recurring item is an income or an expense.'),
      );
    }
    if (amount <= 0) {
      throw ValidationException(tr('The amount must be above zero.'));
    }
    if (endDate != null && dateOnly(endDate).isBefore(dateOnly(startDate))) {
      throw ValidationException(
        tr('The end day cannot be before the first day.'),
      );
    }

    final account = await _db.accountsDao.getById(accountId);
    if (account == null) throw ValidationException(tr('Account not found.'));
    if (account.isArchived && accountId != existing?.accountId) {
      throw ValidationException(
        tr('The account "{name}" is archived.', {'name': account.name}),
      );
    }
    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) throw ValidationException(tr('Category not found.'));
    if (category.type != type.categoryType) {
      final args = {'name': category.name};
      throw ValidationException(
        type == TransactionType.income
            ? tr('The category "{name}" is not an income category.', args)
            : tr('The category "{name}" is not an expense category.', args),
      );
    }
    if (category.isArchived && categoryId != existing?.categoryId) {
      throw ValidationException(
        tr('The category "{name}" is archived.', {'name': category.name}),
      );
    }
    return name;
  }

  RecurringRule _toRule(RecurringRuleRow row) => RecurringRule(
    id: row.id,
    title: row.title,
    type: row.type,
    amount: row.amount,
    accountId: row.accountId,
    categoryId: row.categoryId,
    frequency: row.frequency,
    startDate: row.startDate.toLocal(),
    nextDue: row.nextDue.toLocal(),
    endDate: row.endDate?.toLocal(),
    autoAdd: row.autoAdd,
    remind: row.remind,
    isPaused: row.isPaused,
  );
}
