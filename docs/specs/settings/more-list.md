# The More list

Phone feedback (2026-11-05): "more e baki ja ja ache oigulo aro user friendly and UI ta
aro smooth".

## Behaviour
- **Each group is a card** with thin dividers (`more-group-<heading>`), instead of
  a long flat list.
- **Opened lately** (`more-recent`): under the Help tile, the last four places
  opened from this list as chips (`recent-<route>`), newest first. Nothing before
  the first visit.
- **A short status on a tile** when something needs a look
  (`more-status-<route>`): Loans *2 late*; Backup & export *No backup yet* /
  *Backup 16 days old* (warning from 14 days) / *Backed up today*; Recurring
  *Due today / tomorrow / in N days* when the next item is within 3 days. A late
  loan or an old backup is drawn in the warning color.
- The search box still finds a place by name or by what it is for.

## Rules
- `more_status.dart`: `backupStatus`, `loansStatus`, `recurringStatus`,
  `rememberVisit` (newest first, no repeats, four kept), `parseRecent`.
- The last places are kept in the device setting `more_recent` (route paths,
  comma separated), which stays out of backups (`isDeviceSetting`).

## Tests
`test/features/settings/domain/more_status_test.dart`,
`test/features/settings/presentation/more_list_test.dart`.
