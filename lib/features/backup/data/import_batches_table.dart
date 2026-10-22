import 'package:drift/drift.dart';

/// One CSV import, kept so that it can be undone: the transactions it added
/// carry its id in `transactions.import_batch_id`. It lives on the phone only
/// (it is not in a backup), and goes when the import is undone.
@DataClassName('ImportBatchRow')
class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The name of the file that was imported.
  TextColumn get fileName => text()();

  /// How many transactions the import added.
  IntColumn get transactionCount => integer()();

  /// The ids of the accounts the import created, joined with commas.
  TextColumn get createdAccountIds => text().withDefault(const Constant(''))();

  /// The ids of the categories the import created, joined with commas.
  TextColumn get createdCategoryIds => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
