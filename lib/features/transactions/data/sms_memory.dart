import 'package:hishab/core/database/app_database.dart';

const _prefix = 'sms_account:';

/// Which account the person chose for each kind of SMS (see `SmsEntry.source`),
/// so the next message of the kind goes there without asking.
Future<Map<String, int>> readSmsAccounts(AppDatabase db) async {
  final all = await db.settingsDao.getAll();
  return {
    for (final entry in all.entries)
      if (entry.key.startsWith(_prefix) && int.tryParse(entry.value) != null)
        entry.key.substring(_prefix.length): int.parse(entry.value),
  };
}

Future<void> rememberSmsAccount(AppDatabase db, String source, int accountId) =>
    db.settingsDao.put('$_prefix$source', '$accountId');
