import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/tags/data/tags_dao.dart';
import 'package:hishab/features/tags/domain/tag.dart';

/// Trips and events: making them, renaming and deleting them, and what was
/// spent under each.
class TagsRepository {
  TagsRepository(this._db);

  final AppDatabase _db;

  /// Every tag, the newest first.
  Stream<List<Tag>> watchTags() => _db.tagsDao.watchAll().map(
    (rows) => [for (final row in rows) _toTag(row)],
  );

  /// Every tag with what was spent and received under it, the one used most
  /// recently first.
  Stream<List<TagSummary>> watchSummaries() => _db.tagsDao.watchSummaries().map(
    (rows) => [for (final row in rows) _toSummary(row)],
  );

  Future<Tag?> getTag(int id) async {
    final row = await _db.tagsDao.getById(id);
    return row == null ? null : _toTag(row);
  }

  /// Returns the new tag's id.
  Future<int> createTag(String name) async {
    final clean = await _validatedName(name);
    return _db.tagsDao.insertTag(TagsCompanion.insert(name: clean));
  }

  Future<void> renameTag(int id, String name) async {
    final current = await _db.tagsDao.getById(id);
    if (current == null) throw ValidationException(tr('Tag not found.'));
    final clean = await _validatedName(name, excludeId: id);
    await _db.tagsDao.updateTag(current.copyWith(name: clean));
  }

  /// Deletes the tag. The transactions that carried it are kept.
  Future<void> deleteTag(int id) async {
    await _db.tagsDao.deleteTag(id);
  }

  Future<String> _validatedName(String name, {int? excludeId}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ValidationException(tr('Enter a name.'));
    if (clean.length > maxTagNameLength) {
      throw ValidationException(
        tr('The name must be {max} characters or fewer.', {
          'max': maxTagNameLength,
        }),
      );
    }
    final existing = await _db.tagsDao.findByName(clean);
    if (existing != null && existing.id != excludeId) {
      throw ValidationException(
        tr('There is already a tag called "{name}".', {'name': existing.name}),
      );
    }
    return clean;
  }
}

Tag _toTag(TagRow row) => Tag(id: row.id, name: row.name);

TagSummary _toSummary(TagSummaryRow row) => TagSummary(
  tag: _toTag(row.tag),
  expense: row.expense,
  income: row.income,
  count: row.count,
  firstDate: row.firstDate?.toLocal(),
  lastDate: row.lastDate?.toLocal(),
);
