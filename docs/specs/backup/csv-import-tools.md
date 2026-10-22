# CSV import tools

## Goal
Bringing in two years of a sheet should be something to look at first and to
take back after. The person sees what will change, is helped to match the new
categories with the ones they have, and can undo the whole import.

## Behaviour
- **Income and expense in two columns.** *Income or expense comes from* has a
  fifth choice, *Separate income and expense columns*. The single *Amount*
  field is then replaced by *Income amount* and *Expense amount* (one of the
  two is enough). A row fills one of them: income, or expense. Both filled, none,
  zero or text is a row that cannot be read. A sign is ignored (`-50` in the
  expense column is an expense of 50). Header names like *Income* and *Expense*,
  *Credit* and *Debit*, pick this on their own, but only as a pair; a name with
  `/`, *type*, *category*, *account*, *note* or *desc* in it is not an amount.
- **New account here.** The account section has *New account*: a name and
  *Count it in my total balance*. The account is made at once, with the type
  guessed from its name, and becomes the account for the rows. Turn the switch
  off for old records: the total balance stays as it is.
- **What changes in your accounts.** The preview adds, for each account the
  rows touch, what the import does to its balance (income adds, expense takes,
  a transfer moves from one to the other). *new account* and *not in your
  total balance* are said under the name. Rows that are skipped do not count.
- **Matching a new category.** *Will also be created* lists the new categories.
  A new top-level name that holds, or is held by, the name of a category of the
  same type that the app has (*Transportation* and *Transport*) gets *Looks
  like "Transport", which you have* and **Use it**. The swap button opens the
  category picker for any category of that type. A matched category is listed
  under *Matched with your categories* with a way to take it back. The rows
  then go to that category and none is made. Names under 4 letters and
  archived categories are not suggested. A matching is for the preview it was
  made in.
- **Dates to check.** A row to import whose date is more than 45 days from the
  rows around it (two before, two after; they must agree within 45 days
  themselves, so a file that jumps in time is left alone) is marked. If
  swapping day and month brings it back near them, the note says so (*the day
  and month the wrong way round: 11 Aug 2024?*). The row is still imported. The
  preview says *N rows to check* and has a *To check* filter.
- **Undo.** Each import that adds rows is kept (`import_batches`, schema 17;
  `transactions.import_batch_id`). When it is finished, **Undo this import**
  asks, then removes the transactions that import added. Later, Backup &
  export shows **Undo last import** (file, how many, date) for the latest
  one; after it is undone, the one before shows. The categories and accounts
  the import made are *hidden* (archived), never deleted, and only when
  nothing uses them any more: no transaction, budget, recurring rule,
  challenge, debt or investment, and for a category no active category
  inside it. Entries made by hand are never touched. An import that added
  nothing is not kept.
- **Remembered columns.** After an import the mapping is saved under the names
  of the columns (`import_mappings` in the app settings, the last 8). The next
  file with the same names starts with it, with *The columns are set as they
  were...* above the fields. A saved mapping that does not fit the file (a
  column past the end, a damaged setting) is ignored.

## Rules
- Undo is all or nothing, in one database transaction.
- The batches are on this phone only. They are not in a backup, and a restore
  or *Delete all data* removes them.
- The matching of categories is by `categoryKey` (type and the path of
  names, case and spaces ignored).
- Reading from `.xlsx` is not part of this: the file is still a CSV.

## Tests
- `test/features/backup/domain/import_tools_test.dart`
- `test/features/backup/data/import_undo_test.dart`
- `test/features/backup/presentation/csv_import_screen_test.dart` (*the import
  tools*)
- `test/core/database/migration_test.dart` (version 17)
