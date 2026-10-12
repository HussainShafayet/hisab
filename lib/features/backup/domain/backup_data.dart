import 'dart:convert';

import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_tree.dart'
    show maxCategoryDepth;
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The version of the backup file format. Raise it when the format changes in
/// a way an older app could not read.
///
/// 1: accounts, categories, transactions, budgets.
/// 2: also loans (`debts`) and their payments (`debtPayments`).
/// 3: also recurring items (`recurringRules`). An older file has none of what
/// came after it, and is read as having none.
const backupFormatVersion = 3;

const _appId = 'hishab';

Never _damaged(String message) => throw ValidationException(
  tr('The backup is damaged: {detail}', {'detail': message}),
);

Map<String, Object?> _object(Object? value, String where) {
  if (value is Map<String, Object?>) return value;
  _damaged('$where is not an object.');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) return value;
  _damaged('"$key" is missing.');
}

int _int(Map<String, Object?> json, String key, String where) {
  final value = json[key];
  if (value is int) return value;
  _damaged('$where has no whole number "$key".');
}

int? _intOrNull(Map<String, Object?> json, String key, String where) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  _damaged('$where has a "$key" that is not a whole number.');
}

String _string(Map<String, Object?> json, String key, String where) {
  final value = json[key];
  if (value is String) return value;
  _damaged('$where has no text "$key".');
}

bool _bool(
  Map<String, Object?> json,
  String key,
  String where, {
  bool? orElse,
}) {
  final value = json[key];
  if (value is bool) return value;
  if (value == null && orElse != null) return orElse;
  _damaged('$where has no true/false "$key".');
}

/// A list that may be missing, which is read as empty.
List<Object?> _optionalList(Map<String, Object?> json, String key) =>
    json[key] == null ? const [] : _list(json, key);

DateTime? _dateOrNull(Map<String, Object?> json, String key, String where) =>
    json[key] == null ? null : _date(json, key, where);

DateTime _date(Map<String, Object?> json, String key, String where) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) _damaged('$where has no valid date "$key".');
  return parsed.toUtc();
}

T _enum<T extends Enum>(
  List<T> values,
  Map<String, Object?> json,
  String key,
  String where,
) {
  final name = _string(json, key, where);
  for (final value in values) {
    if (value.name == name) return value;
  }
  _damaged('$where has an unknown "$key": "$name".');
}

String _iso(DateTime date) => date.toUtc().toIso8601String();

class BackupAccount {
  const BackupAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.includeInTotal,
    required this.isArchived,
    required this.createdAt,
  });

  factory BackupAccount.fromJson(Map<String, Object?> json) {
    const where = 'An account';
    return BackupAccount(
      id: _int(json, 'id', where),
      name: _string(json, 'name', where),
      type: _enum(AccountType.values, json, 'type', where),
      openingBalance: _int(json, 'openingBalance', where),
      includeInTotal: _bool(json, 'includeInTotal', where),
      isArchived: _bool(json, 'isArchived', where),
      createdAt: _date(json, 'createdAt', where),
    );
  }

  final int id;
  final String name;
  final AccountType type;
  final int openingBalance;
  final bool includeInTotal;
  final bool isArchived;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'openingBalance': openingBalance,
    'includeInTotal': includeInTotal,
    'isArchived': isArchived,
    'createdAt': _iso(createdAt),
  };
}

class BackupCategory {
  const BackupCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
    required this.icon,
    required this.color,
    required this.isArchived,
    required this.sortOrder,
  });

  factory BackupCategory.fromJson(Map<String, Object?> json) {
    const where = 'A category';
    return BackupCategory(
      id: _int(json, 'id', where),
      name: _string(json, 'name', where),
      type: _enum(CategoryType.values, json, 'type', where),
      parentId: _intOrNull(json, 'parentId', where),
      icon: _string(json, 'icon', where),
      color: _int(json, 'color', where),
      isArchived: _bool(json, 'isArchived', where),
      sortOrder: _int(json, 'sortOrder', where),
    );
  }

  final int id;
  final String name;
  final CategoryType type;
  final int? parentId;
  final String icon;
  final int color;
  final bool isArchived;
  final int sortOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'parentId': parentId,
    'icon': icon,
    'color': color,
    'isArchived': isArchived,
    'sortOrder': sortOrder,
  };
}

class BackupTransaction {
  const BackupTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.date,
    required this.note,
    required this.isAdjustment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupTransaction.fromJson(Map<String, Object?> json) {
    const where = 'A transaction';
    return BackupTransaction(
      id: _int(json, 'id', where),
      type: _enum(TransactionType.values, json, 'type', where),
      amount: _int(json, 'amount', where),
      accountId: _int(json, 'accountId', where),
      toAccountId: _intOrNull(json, 'toAccountId', where),
      categoryId: _intOrNull(json, 'categoryId', where),
      date: _date(json, 'date', where),
      note: _string(json, 'note', where),
      isAdjustment: _bool(json, 'isAdjustment', where, orElse: false),
      createdAt: _date(json, 'createdAt', where),
      updatedAt: _date(json, 'updatedAt', where),
    );
  }

  final int id;
  final TransactionType type;

  /// In poisha.
  final int amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final DateTime date;
  final String note;
  final bool isAdjustment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'accountId': accountId,
    'toAccountId': toAccountId,
    'categoryId': categoryId,
    'date': _iso(date),
    'note': note,
    'isAdjustment': isAdjustment,
    'createdAt': _iso(createdAt),
    'updatedAt': _iso(updatedAt),
  };
}

class BackupBudget {
  const BackupBudget({
    required this.id,
    required this.month,
    required this.categoryId,
    required this.amount,
  });

  factory BackupBudget.fromJson(Map<String, Object?> json) {
    const where = 'A budget';
    return BackupBudget(
      id: _int(json, 'id', where),
      month: _string(json, 'month', where),
      categoryId: _intOrNull(json, 'categoryId', where),
      amount: _int(json, 'amount', where),
    );
  }

  final int id;

  /// `YYYY-MM`.
  final String month;
  final int? categoryId;

  /// In poisha.
  final int amount;

  Map<String, Object?> toJson() => {
    'id': id,
    'month': month,
    'categoryId': categoryId,
    'amount': amount,
  };
}

class BackupDebt {
  const BackupDebt({
    required this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.openedOn,
    required this.dueOn,
    required this.note,
    required this.accountId,
    required this.transactionId,
    required this.createdAt,
  });

  factory BackupDebt.fromJson(Map<String, Object?> json) {
    const where = 'A loan';
    return BackupDebt(
      id: _int(json, 'id', where),
      person: _string(json, 'person', where),
      direction: _enum(DebtDirection.values, json, 'direction', where),
      amount: _int(json, 'amount', where),
      openedOn: _date(json, 'openedOn', where),
      dueOn: _dateOrNull(json, 'dueOn', where),
      note: _string(json, 'note', where),
      accountId: _intOrNull(json, 'accountId', where),
      transactionId: _intOrNull(json, 'transactionId', where),
      createdAt: _date(json, 'createdAt', where),
    );
  }

  final int id;
  final String person;
  final DebtDirection direction;
  final int amount;
  final DateTime openedOn;
  final DateTime? dueOn;
  final String note;
  final int? accountId;
  final int? transactionId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'person': person,
    'direction': direction.name,
    'amount': amount,
    'openedOn': _iso(openedOn),
    'dueOn': dueOn == null ? null : _iso(dueOn!),
    'note': note,
    'accountId': accountId,
    'transactionId': transactionId,
    'createdAt': _iso(createdAt),
  };
}

class BackupRecurringRule {
  const BackupRecurringRule({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    required this.endDate,
    required this.autoAdd,
    required this.remind,
    required this.isPaused,
    required this.createdAt,
  });

  factory BackupRecurringRule.fromJson(Map<String, Object?> json) {
    const where = 'A recurring item';
    return BackupRecurringRule(
      id: _int(json, 'id', where),
      title: _string(json, 'title', where),
      type: _enum(TransactionType.values, json, 'type', where),
      amount: _int(json, 'amount', where),
      accountId: _int(json, 'accountId', where),
      categoryId: _int(json, 'categoryId', where),
      frequency: _enum(RecurrenceFrequency.values, json, 'frequency', where),
      startDate: _date(json, 'startDate', where),
      nextDue: _date(json, 'nextDue', where),
      endDate: _dateOrNull(json, 'endDate', where),
      autoAdd: _bool(json, 'autoAdd', where),
      remind: _bool(json, 'remind', where),
      isPaused: _bool(json, 'isPaused', where),
      createdAt: _date(json, 'createdAt', where),
    );
  }

  final int id;
  final String title;
  final TransactionType type;
  final int amount;
  final int accountId;
  final int categoryId;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime nextDue;
  final DateTime? endDate;
  final bool autoAdd;
  final bool remind;
  final bool isPaused;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'amount': amount,
    'accountId': accountId,
    'categoryId': categoryId,
    'frequency': frequency.name,
    'startDate': _iso(startDate),
    'nextDue': _iso(nextDue),
    'endDate': endDate == null ? null : _iso(endDate!),
    'autoAdd': autoAdd,
    'remind': remind,
    'isPaused': isPaused,
    'createdAt': _iso(createdAt),
  };
}

class BackupDebtPayment {
  const BackupDebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidOn,
    required this.note,
    required this.accountId,
    required this.transactionId,
    required this.createdAt,
  });

  factory BackupDebtPayment.fromJson(Map<String, Object?> json) {
    const where = 'A loan payment';
    return BackupDebtPayment(
      id: _int(json, 'id', where),
      debtId: _int(json, 'debtId', where),
      amount: _int(json, 'amount', where),
      paidOn: _date(json, 'paidOn', where),
      note: _string(json, 'note', where),
      accountId: _intOrNull(json, 'accountId', where),
      transactionId: _intOrNull(json, 'transactionId', where),
      createdAt: _date(json, 'createdAt', where),
    );
  }

  final int id;
  final int debtId;
  final int amount;
  final DateTime paidOn;
  final String note;
  final int? accountId;
  final int? transactionId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'debtId': debtId,
    'amount': amount,
    'paidOn': _iso(paidOn),
    'note': note,
    'accountId': accountId,
    'transactionId': transactionId,
    'createdAt': _iso(createdAt),
  };
}

/// Everything in the app, as it is written to and read from a backup file.
/// Money is whole poisha, dates are UTC, and every row keeps its id, so the
/// links between accounts, categories and transactions survive a restore.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    this.debts = const [],
    this.debtPayments = const [],
    this.recurringRules = const [],
  });

  /// Reads and checks backup text. Throws a [ValidationException] that says
  /// what is wrong when it is not a Hishab backup, was made by a newer app, or
  /// is damaged (a missing field, a transaction that points to an account
  /// that is not in the file, ...). Nothing is changed by reading.
  factory BackupData.decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw ValidationException(tr('This file is not a Hishab backup.'));
    }
    return BackupData.fromJson(json);
  }

  factory BackupData.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['app'] != _appId) {
      throw ValidationException(tr('This file is not a Hishab backup.'));
    }
    final version = json['formatVersion'];
    if (version is! int || version < 1) {
      _damaged('it has no format version.');
    }
    if (version > backupFormatVersion) {
      throw ValidationException(
        tr(
          'This backup was made by a newer version of Hishab. Update the app '
          'to restore it.',
        ),
      );
    }

    final data = BackupData(
      exportedAt: _date(json, 'exportedAt', 'The backup'),
      accounts: [
        for (final item in _list(json, 'accounts'))
          BackupAccount.fromJson(_object(item, 'An account')),
      ],
      categories: [
        for (final item in _list(json, 'categories'))
          BackupCategory.fromJson(_object(item, 'A category')),
      ],
      transactions: [
        for (final item in _list(json, 'transactions'))
          BackupTransaction.fromJson(_object(item, 'A transaction')),
      ],
      budgets: [
        for (final item in _list(json, 'budgets'))
          BackupBudget.fromJson(_object(item, 'A budget')),
      ],
      debts: [
        for (final item in _optionalList(json, 'debts'))
          BackupDebt.fromJson(_object(item, 'A loan')),
      ],
      debtPayments: [
        for (final item in _optionalList(json, 'debtPayments'))
          BackupDebtPayment.fromJson(_object(item, 'A loan payment')),
      ],
      recurringRules: [
        for (final item in _optionalList(json, 'recurringRules'))
          BackupRecurringRule.fromJson(_object(item, 'A recurring item')),
      ],
    );
    data._checkLinks();
    return data;
  }

  final DateTime exportedAt;
  final List<BackupAccount> accounts;
  final List<BackupCategory> categories;
  final List<BackupTransaction> transactions;
  final List<BackupBudget> budgets;
  final List<BackupDebt> debts;
  final List<BackupDebtPayment> debtPayments;
  final List<BackupRecurringRule> recurringRules;

  Map<String, Object?> toJson() => {
    'app': _appId,
    'formatVersion': backupFormatVersion,
    'exportedAt': _iso(exportedAt),
    'accounts': [for (final a in accounts) a.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'transactions': [for (final t in transactions) t.toJson()],
    'budgets': [for (final b in budgets) b.toJson()],
    'debts': [for (final d in debts) d.toJson()],
    'debtPayments': [for (final p in debtPayments) p.toJson()],
    'recurringRules': [for (final r in recurringRules) r.toJson()],
  };

  /// The categories with every category after the one it is inside, so they
  /// can be saved one by one without a category pointing at one that is not
  /// there yet.
  List<BackupCategory> get categoriesParentsFirst {
    final byId = {for (final c in categories) c.id: c};
    int level(BackupCategory category) {
      var level = 0;
      var current = category;
      while (level <= categories.length) {
        final parent = byId[current.parentId];
        if (parent == null) break;
        level++;
        current = parent;
      }
      return level;
    }

    final withLevel = [for (final c in categories) (level: level(c), c: c)];
    withLevel.sort((a, b) => a.level.compareTo(b.level));
    return [for (final entry in withLevel) entry.c];
  }

  /// The backup as text, ready to be written to a file.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Every id is used once and every link points at something in the file.
  void _checkLinks() {
    Set<int> uniqueIds(Iterable<int> ids, String what) {
      final set = <int>{};
      for (final id in ids) {
        if (!set.add(id)) _damaged('two $what have the id $id.');
      }
      return set;
    }

    final accountIds = uniqueIds(accounts.map((a) => a.id), 'accounts');
    final categoryIds = uniqueIds(categories.map((c) => c.id), 'categories');
    uniqueIds(transactions.map((t) => t.id), 'transactions');
    uniqueIds(budgets.map((b) => b.id), 'budgets');
    final debtIds = uniqueIds(debts.map((d) => d.id), 'loans');
    uniqueIds(debtPayments.map((p) => p.id), 'loan payments');
    final transactionIds = {for (final t in transactions) t.id};
    void checkLoanLinks(String what, int id, int? account, int? transaction) {
      if (account != null && !accountIds.contains(account)) {
        _damaged('$what $id points to an account that is not in the file.');
      }
      if (transaction != null && !transactionIds.contains(transaction)) {
        _damaged('$what $id points to a transaction that is not in the file.');
      }
    }

    uniqueIds(recurringRules.map((r) => r.id), 'recurring items');
    for (final r in recurringRules) {
      if (!accountIds.contains(r.accountId)) {
        _damaged(
          'recurring item ${r.id} points to an account that is not in the file.',
        );
      }
      if (!categoryIds.contains(r.categoryId)) {
        _damaged(
          'recurring item ${r.id} points to a category that is not in the file.',
        );
      }
    }
    for (final d in debts) {
      checkLoanLinks('loan', d.id, d.accountId, d.transactionId);
    }
    for (final p in debtPayments) {
      if (!debtIds.contains(p.debtId)) {
        _damaged(
          'loan payment ${p.id} points to a loan that is not in the file.',
        );
      }
      checkLoanLinks('loan payment', p.id, p.accountId, p.transactionId);
    }

    final parents = {for (final c in categories) c.id: c.parentId};
    for (final category in categories) {
      final parentId = category.parentId;
      if (parentId == null) continue;
      if (!categoryIds.contains(parentId)) {
        _damaged(
          'category ${category.id} has a parent that is not in the file.',
        );
      }
      // Walk up to the top: a loop, or a tree deeper than the app allows,
      // means the file is not one the app made.
      var level = 1;
      int? up = parentId;
      while (up != null) {
        level++;
        if (up == category.id || level > maxCategoryDepth) {
          _damaged('category ${category.id} is nested in a loop or too deep.');
        }
        up = parents[up];
      }
    }
    for (final t in transactions) {
      if (!accountIds.contains(t.accountId)) {
        _damaged(
          'transaction ${t.id} points to an account that is not in the file.',
        );
      }
      final to = t.toAccountId;
      if (to != null && !accountIds.contains(to)) {
        _damaged(
          'transaction ${t.id} points to an account that is not in the file.',
        );
      }
      final category = t.categoryId;
      if (category != null && !categoryIds.contains(category)) {
        _damaged(
          'transaction ${t.id} points to a category that is not in the file.',
        );
      }
    }
    for (final b in budgets) {
      final category = b.categoryId;
      if (category != null && !categoryIds.contains(category)) {
        _damaged(
          'budget ${b.id} points to a category that is not in the file.',
        );
      }
    }
  }
}
