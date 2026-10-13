# Trips and events (tags)

## Goal
See what a trip or an event cost in all (a tour, Eid, a wedding) by tagging
the expenses that belong to it.

## Behaviour
- **Add / edit transaction**: an income or expense has a *Trip or event
  (optional)* row of chips: the newest 8 tags (and the chosen one) and *New
  tag*. Tapping a chip chooses it, tapping again clears it. *New tag* asks for a
  name and chooses it. "Save & new" keeps the tag, since the next one is
  usually in the same trip. A transfer has no tag row.
- A transaction with a tag shows `#Name` in its row.
- **More > Trips & events** lists the tags, the one used most recently first,
  each with its transaction count, its first and last day and what was spent.
  *New tag* makes one. Empty, it invites the first.
- A tag opens to *Spent in all*, what was *Received* (when there is some), the
  count and days, and every transaction under it (tap to edit). Its menu
  renames or deletes it.
- Deleting a tag asks first; its transactions stay without it.

## Rules
- A name is 1 to 40 characters and unique whatever the case.
- Only income and expense can have a tag (a transfer cannot), and the tag must
  exist.
- Totals leave out balance adjustments.
- `transactions.tag_id` is not a database foreign key (so it can be added to an
  existing table); deleting a tag clears it on its transactions.
- Schema version 9 adds `tags` and `transactions.tag_id`. Backup format 7 saves
  both; an older file reads as having none. The spreadsheet export gets a `Tag`
  column.

## Tests
- `test/features/tags/data/tags_repository_test.dart`
- `test/features/tags/presentation/tags_ui_test.dart`
- `test/core/database/migration_test.dart` (version 8 to 9)
