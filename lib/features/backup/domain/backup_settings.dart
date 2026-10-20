/// When this phone last made a backup (an ISO date), and until when the
/// reminder to make one is put off. Both belong to this phone, not to the
/// data, so they are not in a backup.
const lastBackupKey = 'last_backup_at';
const backupSnoozedUntilKey = 'backup_snoozed_until';

/// Settings that belong to this phone and its history, not to the person's
/// choices: they stay out of a backup and a restore leaves them alone. These
/// are the markers of alerts that were already shown, of challenges that were
/// already cheered, and the two keys above.
bool isDeviceSetting(String key) =>
    key == lastBackupKey ||
    key == backupSnoozedUntilKey ||
    key.startsWith('alert_') ||
    key.startsWith('challenge_cheered_');

/// The most settings a backup can hold, so a damaged file cannot fill the
/// phone.
const maxBackupSettings = 500;
