# Choosing several transactions

## Goal
After an import, or any busy month, one row at a time is too slow: moving 30
"Rickshaw" rows into the right category, or deleting a day of mistakes.

## Behaviour
- **Start.** A long press on a row opens the sheet; its first row is **Select
  several** (Edit, Duplicate and Delete are still there). The row is picked and
  the app bar becomes: a cross, *N selected*, and four buttons: **Select all**,
  **Change category**, **Change account**, **Delete**. (No button was added to
  the normal app bar: with the bell, help, search and filter it was full.)
- **Choosing.** A tap, or a long press, picks or unpicks a row. A picked row is
  tinted with a tick where the picture was. There is no swiping while choosing.
  *Select all* picks the rows on the screen (this month and this filter). The
  count only holds rows that are on the screen. The cross, or the back
  button, leaves choosing (back first, the screen after).
- The three actions are off while nothing is picked.
- **Delete** asks *Delete N transactions?* ("Account balances follow at once.
  For a few seconds you can undo it."). Then one message, *N transactions
  deleted*, with **Undo** (8 seconds) that puts them all back with the same
  ids.
- **Change category.** Only for expenses alone or income alone (a transfer and
  a balance fix have no category to change). Otherwise a message says so and
  nothing opens. The category picker (no *Add*) lists the categories of that
  type. Then *N transactions moved to Food › Groceries*, with **Undo**.
- **Change account.** Only for expenses and income (not a transfer, which has
  two accounts, not a balance fix). A sheet lists the active accounts. Then
  *N transactions moved to bKash*, with **Undo**. A transaction with dollars
  needs a credit card as the new account.

## Rules (`TransactionsRepository`)
- `deleteTransactions`, `changeCategories`, `changeAccounts` each run in one
  database transaction: all or nothing. A category must exist, not be
  archived and be of the type of every transaction; an account must exist and
  not be archived. The two *change* methods return what each had, for
  `restoreCategories` and `restoreAccounts` (they put it back without the
  checks, since the old one may be archived by now).
- The month and the filter keep working while choosing; what is no longer on
  the screen is no longer counted.

## Tests
- `test/features/transactions/data/bulk_edit_test.dart`
- `test/features/transactions/presentation/bulk_edit_ui_test.dart`
