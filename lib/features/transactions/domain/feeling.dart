/// How a spending felt afterwards. Saved by name: never rename a value without
/// a migration.
enum Feeling {
  /// It had to be bought.
  need,

  /// It was wanted, and that is fine.
  want,

  /// It should not have been bought.
  regret,
}
