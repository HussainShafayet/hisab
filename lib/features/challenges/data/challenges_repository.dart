import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/challenges/data/challenges_dao.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';

/// Everything the UI needs for spending challenges: reading them with what was
/// spent, and making, changing and deleting them, with the rules checked in
/// one place.
class ChallengesRepository {
  ChallengesRepository(this._db);

  /// A win older than this many days is not a reason for confetti any more.
  static const newWinDays = 7;

  final AppDatabase _db;

  /// Every challenge, the latest start first, with what was spent in it.
  Stream<List<ChallengeItem>> watchChallenges() => _db.challengesDao
      .watchWithSpent()
      .map((rows) => rows.map(_toItem).toList());

  Future<ChallengeItem?> getChallenge(int id) async {
    final row = await _db.challengesDao.getWithSpent(id);
    return row == null ? null : _toItem(row);
  }

  /// Makes a challenge and returns its id. [limit] (poisha) is only for
  /// [ChallengeKind.limit]; a no-spend challenge has none.
  Future<int> create({
    required String title,
    required ChallengeKind kind,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 0,
    int? categoryId,
  }) async {
    final values = await _checked(
      title: title,
      kind: kind,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      categoryId: categoryId,
    );
    return _db.challengesDao.insertChallenge(values);
  }

  Future<void> update(
    int id, {
    required String title,
    required ChallengeKind kind,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 0,
    int? categoryId,
  }) async {
    final existing = await _db.challengesDao.getById(id);
    if (existing == null) {
      throw ValidationException(tr('Challenge not found.'));
    }
    final values = await _checked(
      title: title,
      kind: kind,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      categoryId: categoryId,
      keepingCategoryId: existing.categoryId,
    );
    await _db.challengesDao.updateChallenge(
      existing.copyWith(
        title: values.title.value,
        kind: values.kind.value,
        categoryId: Value(values.categoryId.value),
        limitAmount: values.limitAmount.value,
        startDate: values.startDate.value,
        endDate: values.endDate.value,
      ),
    );
  }

  /// Remembers which won challenges have been seen, and says whether one of
  /// them is a win that is new, which ended in the last [newWinDays] days and
  /// is worth confetti. A win is only cheered once.
  Future<bool> takeNewWins(List<ChallengeItem> items, DateTime today) async {
    final settings = await _db.settingsDao.getAll();
    var cheer = false;
    for (final item in items) {
      if (item.stateOn(today) != ChallengeState.won) continue;
      final key = 'challenge_cheered_${item.challenge.id}';
      if (settings[key] == 'true') continue;
      await _db.settingsDao.put(key, 'true');
      if (daysBetween(item.challenge.endDate, dateOnly(today)) <= newWinDays) {
        cheer = true;
      }
    }
    return cheer;
  }

  Future<void> delete(int id) async {
    await _db.challengesDao.deleteChallenge(id);
  }

  /// The values to save, after the rules. A challenge keeps the category it
  /// already had even if that has been archived since ([keepingCategoryId]).
  Future<ChallengesCompanion> _checked({
    required String title,
    required ChallengeKind kind,
    required DateTime startDate,
    required DateTime endDate,
    required int limit,
    required int? categoryId,
    int? keepingCategoryId,
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      throw ValidationException(tr('Give the challenge a name.'));
    }
    if (name.length > maxChallengeTitleLength) {
      throw ValidationException(
        tr('The name can have at most {n} letters.', {
          'n': maxChallengeTitleLength,
        }),
      );
    }
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ValidationException(tr('The end cannot be before the start.'));
    }
    if (daysBetween(start, end) + 1 > maxChallengeDays) {
      throw ValidationException(tr('A challenge can last at most a year.'));
    }
    if (kind == ChallengeKind.limit && limit <= 0) {
      throw ValidationException(tr('The limit must be above zero.'));
    }
    if (categoryId != null && categoryId != keepingCategoryId) {
      await _requireChallengeCategory(categoryId);
    }
    return ChallengesCompanion.insert(
      title: name,
      kind: kind,
      limitAmount: kind == ChallengeKind.noSpend ? 0 : limit,
      startDate: start,
      endDate: end,
      categoryId: Value(categoryId),
    );
  }

  Future<void> _requireChallengeCategory(int categoryId) async {
    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) {
      throw ValidationException(tr('Category not found.'));
    }
    if (category.type != CategoryType.expense) {
      throw ValidationException(
        tr('Only an expense category can have a challenge.'),
      );
    }
    if (category.isArchived) {
      throw ValidationException(
        tr('The category "{name}" is archived.', {'name': category.name}),
      );
    }
  }

  ChallengeItem _toItem(ChallengeWithSpent row) {
    final c = row.challenge;
    return ChallengeItem(
      challenge: Challenge(
        id: c.id,
        title: c.title,
        kind: c.kind,
        categoryId: c.categoryId,
        limit: c.limitAmount,
        startDate: dateOnly(c.startDate),
        endDate: dateOnly(c.endDate),
        createdAt: c.createdAt,
      ),
      spent: row.spent,
      categoryName: row.categoryName,
    );
  }
}
