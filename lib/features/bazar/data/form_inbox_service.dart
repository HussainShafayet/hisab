import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';
import 'package:hishab/features/bazar/domain/form_inbox.dart';

/// Takes what other people write in a Google Form onto the bazar list. See
/// docs/specs/bazar/google-form-inbox.md.
class FormInboxService {
  const FormInboxService({
    required this.db,
    required this.repository,
    required this.gateway,
  });

  final AppDatabase db;
  final BazarRepository repository;
  final FormInboxGateway gateway;

  /// Reads the sheet at [link] to see it works. Throws [ValidationException]
  /// for a link that is not a published sheet and [FormInboxException] when
  /// Google does not show it. Returns how many answers it holds.
  Future<int> check(String link) async {
    final rows = readFormRows(await gateway.fetch(sheetCsvUri(link)));
    return rows.length;
  }

  /// Starts taking the answers from [link]. With [takeExisting] the answers
  /// already in the sheet go on the list; without it only the ones that come
  /// later do. [formLink] is the link of the form itself, kept so it can be sent
  /// to the people who add to the list.
  Future<FormInboxResult> link(
    String link, {
    String? formLink,
    required bool takeExisting,
    required DateTime now,
  }) async {
    final uri = sheetCsvUri(link);
    final rows = readFormRows(await gateway.fetch(uri));
    await db.settingsDao.put(formCsvKey, uri.toString());
    final form = formLink?.trim() ?? '';
    await db.settingsDao.put(formLinkKey, form.isEmpty ? null : form);
    await db.settingsDao.put(
      formImportedKey,
      '${takeExisting ? 0 : rows.length}',
    );
    await db.settingsDao.put(formProblemKey, null);
    await db.settingsDao.put(formDetailKey, null);
    return sync(now);
  }

  /// Stops taking answers. What is on the list stays.
  Future<void> unlink() async {
    for (final key in [
      formCsvKey,
      formLinkKey,
      formImportedKey,
      lastFormSyncKey,
      formProblemKey,
      formDetailKey,
    ]) {
      await db.settingsDao.put(key, null);
    }
  }

  /// Puts the answers that came since the last time on the list. Does nothing
  /// while no sheet is linked. A problem is kept (see [FormInboxStatus]) and not
  /// thrown.
  Future<FormInboxResult> sync(DateTime now) async {
    final saved = await db.settingsDao.getAll();
    final link = saved[formCsvKey];
    if (link == null) return const FormInboxResult();
    try {
      final rows = readFormRows(await gateway.fetch(Uri.parse(link)));
      final plan = planFormImport(
        rows: rows,
        imported: int.tryParse(saved[formImportedKey] ?? '') ?? rows.length,
      );
      var added = 0;
      for (final row in plan.toAdd) {
        try {
          await repository.addItem(row.name, quantity: row.quantity);
          added++;
        } on ValidationException {
          // An answer that is not a good name is passed over.
        }
      }
      await db.settingsDao.put(formImportedKey, '${plan.imported}');
      await db.settingsDao.put(lastFormSyncKey, now.toIso8601String());
      await db.settingsDao.put(formProblemKey, null);
      await db.settingsDao.put(formDetailKey, null);
      return FormInboxResult(added: added);
    } on FormInboxException catch (error) {
      await db.settingsDao.put(formProblemKey, error.problem.name);
      await db.settingsDao.put(formDetailKey, error.detail);
    } on Object catch (error) {
      await db.settingsDao.put(formProblemKey, FormInboxProblem.failed.name);
      await db.settingsDao.put(formDetailKey, '$error');
    }
    return const FormInboxResult();
  }
}

/// What a sync did.
class FormInboxResult {
  const FormInboxResult({this.added = 0});

  /// New items put on the list.
  final int added;
}

/// What the form inbox did last.
class FormInboxStatus {
  const FormInboxStatus({
    this.linked = false,
    this.formLink,
    this.lastSynced,
    this.problem,
    this.detail,
  });

  final bool linked;

  /// The link of the form itself, if it was given.
  final String? formLink;
  final DateTime? lastSynced;
  final FormInboxProblem? problem;
  final String? detail;

  factory FormInboxStatus.fromSettings(Map<String, String> saved) {
    final name = saved[formProblemKey];
    return FormInboxStatus(
      linked: saved[formCsvKey] != null,
      formLink: saved[formLinkKey],
      lastSynced: DateTime.tryParse(saved[lastFormSyncKey] ?? ''),
      problem: FormInboxProblem.values
          .where((problem) => problem.name == name)
          .firstOrNull,
      detail: saved[formDetailKey],
    );
  }
}
