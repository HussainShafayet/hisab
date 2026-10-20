import 'package:drift/drift.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

/// Spending challenges. How much was spent in one is worked out from the
/// transactions, never saved.
@DataClassName('ChallengeRow')
class Challenges extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title =>
      text().withLength(min: 1, max: maxChallengeTitleLength)();

  TextColumn get kind => textEnum<ChallengeKind>()();

  /// The category the challenge is about (and everything inside it), or null
  /// for all spending.
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// In poisha. Zero for a no-spend challenge.
  IntColumn get limitAmount => integer()();

  /// The first and the last day, both included, at local midnight.
  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime()();

  /// When it is over, the same challenge starts again for the same number of
  /// days.
  BoolColumn get repeats => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (limit_amount >= 0)',
    'CHECK (end_date >= start_date)',
  ];
}
