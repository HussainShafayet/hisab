# Add several

## Goal
Enter a handful of transactions (expenses, incomes, transfers) on one screen
and save them with one tap, instead of walking through the form once for each.

## Behaviour
- **Add transaction** has a *Add several* button in its app bar (only when
  adding a plain new transaction, not when editing, copying, paying a card
  bill or checking out the bazar list). It opens `/add/several`.
- The screen starts with **one row**; *Add row* adds more. A new row starts
  like the one before it (same type, same account, and for a transfer the same
  second account), because the next one is usually alike.
- A row has: its own type (Expense / Income / Transfer), amount, account
  (the account money leaves, or arrives in for an income), category (not for a
  transfer), the second account (transfer only) and a note. Rows may use the
  same accounts and categories or different ones. One date (Today / Yesterday /
  a picked day) is shared by all rows.
- **Paste lines** (the clipboard button in the app bar) opens a box for
  lines, one entry on each: `rickshaw 50`, `lunch 120 bkash`, `+salary 30k`.
  *Paste from the clipboard* adds what the phone has copied. *Add rows* makes
  a row of each line, read like the quick-type line of the add form
  (`draftsFromLines`, `parseQuickEntry`): the amount, the account word (else
  the account of the last row), the category and the note. Blank rows give
  way, the rows already filled in stay, a line with no amount still makes a
  row to finish, and a line with nothing in it is skipped. A notice at the
  top says *Added 3 rows. Check them and save.* (not a snack bar, which
  would cover the Save button) or *Nothing to add: write one entry on each
  line.* A day word in a line is not read: the rows share the date.
- Fee, tag, feeling and dollars are not on this screen; use the single form.
- Texts follow the rows: the row title names its type and number
  (*Row 2 · Transfer*), the button says *Save* for one row and *Save all 3*
  for three, the results say how many were saved.

## Saving
- One tap on the button. The rows are saved **one after the other, each on its
  own** (`TransactionsRepository.addTransactions`). A row that fails does not
  stop the others and does not undo the ones saved before it.
- A row with no amount, no category and no note is **blank** and is skipped
  (it is not counted on the button either). The button is off while every row
  is blank, and while saving (no double tap, so no duplicates).
- Every row is checked first (amount, account, category, second account); the
  rest of the rules (archived account, wrong category type, ...) are checked
  by the repository when the row is saved.
- A saved row **leaves the screen**. A row with a mistake stays, with its
  reason under it, and a banner at the top says *3 saved, 2 left to fix*. After
  fixing, the same button saves what is left, so nothing is saved twice.
- When every row was saved the screen closes (returning `true`, which also
  closes the single form that opened it) and a message says how many were
  saved.

## Rules
- Pure checks: `parseBatchDraft` in `transactions/domain/batch_rows.dart`
  (reuses the texts of the single form).
- Same accounts in several rows are fine; going below zero is not blocked
  here, as in the single form (the accounts screen warns).
- Typing in a row clears its error.

## Tests
- `test/features/transactions/domain/batch_rows_test.dart` - the row checks.
- `test/features/transactions/data/add_transactions_test.dart` - saving rows
  one by one, a bad row not stopping the rest.
- `test/features/transactions/presentation/add_several_test.dart` - the
  screen: rows, dynamic texts, partial save, closing.
