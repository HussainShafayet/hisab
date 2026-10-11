/// Stored in the database by name: never rename a value without a migration.
/// The CHECK constraint in `transactions_table.dart` also mentions `transfer`.
enum TransactionType { income, expense, transfer }
