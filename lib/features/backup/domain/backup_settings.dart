/// When this phone last made a backup (an ISO date), and until when the
/// reminder to make one is put off. Both belong to this phone, not to the
/// data, so they are not in a backup.
const lastBackupKey = 'last_backup_at';
const backupSnoozedUntilKey = 'backup_snoozed_until';

/// When the automatic backup last wrote its file, and why it could not (an
/// [AutoBackupProblem] name). They belong to this phone too.
const lastAutoBackupKey = 'last_auto_backup_at';
const autoBackupProblemKey = 'auto_backup_problem';

/// The backup to Google Drive: whether it is on, which account, when it last
/// saved, and what went wrong. The account and the choice belong to this phone,
/// so they are not in a backup either.
const driveEnabledKey = 'drive_backup_on';
const driveEmailKey = 'drive_backup_email';
const lastDriveBackupKey = 'last_drive_backup_at';
const driveProblemKey = 'drive_backup_problem';
const driveDetailKey = 'drive_backup_detail';

/// The bazar list taking new items from a Google Form: the link of its
/// published responses sheet, the link of the form (to send to others), how
/// many rows were taken, when it last worked and what went wrong. They belong
/// to this phone.
const formCsvKey = 'bazar_form_csv';
const formLinkKey = 'bazar_form_link';
const formImportedKey = 'bazar_form_imported';
const lastFormSyncKey = 'last_form_sync_at';
const formProblemKey = 'bazar_form_problem';
const formDetailKey = 'bazar_form_detail';

/// Settings that belong to this phone and its history, not to the person's
/// choices: they stay out of a backup and a restore leaves them alone. These
/// are the markers of alerts that were already shown, of challenges that were
/// already cheered, and the two keys above.
bool isDeviceSetting(String key) =>
    key == lastBackupKey ||
    key == backupSnoozedUntilKey ||
    key == lastAutoBackupKey ||
    key == autoBackupProblemKey ||
    key == driveEnabledKey ||
    key == driveEmailKey ||
    key == lastDriveBackupKey ||
    key == driveProblemKey ||
    key == driveDetailKey ||
    key == formCsvKey ||
    key == formLinkKey ||
    key == formImportedKey ||
    key == lastFormSyncKey ||
    key == formProblemKey ||
    key == formDetailKey ||
    key.startsWith('alert_') ||
    key.startsWith('challenge_cheered_');

/// The most settings a backup can hold, so a damaged file cannot fill the
/// phone.
const maxBackupSettings = 500;
