# Loans (dhar / baki)

## Goal
Keep track of money lent to people (they will pay it back) and money borrowed
from people (I will pay it back), and tick it off as it is paid back.

## Behaviour
More → **Loans** (বাংলা: ধার ও বাকি).

- **List**: a summary on top, "To get back" (money people owe me) and "To pay
  back" (money I owe), plus "N loans are overdue" when any is late. Then one
  card per open loan: person, "They owe you" / "You owe", what is left, a
  progress bar, "Paid ৳400.00 of ৳1,000.00", and when it is due ("Due 20 Oct",
  "Due today", "Overdue by 3 days"). Late loans come first, then by due day,
  then the newest. "Show settled" brings the paid-back loans in (last, with
  "Settled").
- **New loan**: *I lent* or *I borrowed*, the person (one-tap chips for names
  used before), the amount, the day it was given, an optional day to pay back
  by, a note, and optionally an account.
- **Account**: with an account chosen the account balance moves (see Rules);
  without, the loan is just a note.
- **One loan**: what is left, the progress, the day given, the due day, the
  note and the payments (newest first). **Add payment** (amount filled with
  what is left, a day, a note, an account), **Mark as paid** (pays what is left
  today), delete a payment, edit (name, due day, note), delete the loan.

## Rules
- An amount is above zero. A due day is not before the day it was given. A name
  is required (at most 60 characters), a note at most 500.
- A payment cannot be more than what is left. A loan is settled when nothing is
  left.
- With an account, the balance moves through a transaction that is a
  *correction* (`is_adjustment`) in a **Loans** category: lending sends money
  out (expense type), borrowing brings it in (income type), a payment received
  brings it in, a payment made sends it out. Corrections are in the account
  balance but not in income, expense or budgets, so lending is not spending.
  The transaction list says "… · not counted in totals".
- Deleting a payment or a loan also deletes the transactions it made, so the
  balances go back. Deleting such a transaction from the list does not stop the
  loan from being deleted.
- The amount, the direction and the account of a loan cannot be edited: delete
  it and make it again.
- Archived accounts cannot be used. Settled loans are not in the totals.
- Backup format version 2 holds loans (`debts`) and payments (`debtPayments`);
  a version 1 file is read as having none. Restore replaces loans like the
  rest.

## Tests
- `test/features/debts/domain/debt_test.dart`
- `test/features/debts/data/debts_repository_test.dart`
- `test/features/debts/data/debts_backup_test.dart`
- `test/features/debts/presentation/debts_screen_test.dart`
- `test/core/database/migration_test.dart` (version 3 to 4)
- `test/features/transactions/presentation/small_screen_test.dart` (the loan
  screens at 360 dp, text x1.0 and x1.5)
