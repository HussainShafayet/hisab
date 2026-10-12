import 'package:drift/drift.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Incomes and expenses that repeat. The days are dates (midnight, local).
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 60)();

  /// Income or expense (a check keeps transfers out).
  TextColumn get type => textEnum<TransactionType>()();

  IntColumn get amount => integer()();

  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();

  TextColumn get frequency => textEnum<RecurrenceFrequency>()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get nextDue => dateTime()();

  DateTimeColumn get endDate => dateTime().nullable()();

  BoolColumn get autoAdd => boolean().withDefault(const Constant(false))();

  BoolColumn get remind => boolean().withDefault(const Constant(true))();

  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    "CHECK (type IN ('income', 'expense'))",
  ];
}
