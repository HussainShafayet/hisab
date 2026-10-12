# Loans (dhar / baki)

## Goal
Keep track of money lent to people (they will pay it back) and money borrowed
from people (I will pay it back), tick it off as it is paid, and see in one
place what is left between me and each person. Credit card bills show up here
too, on the "I'll give" side (see [credit cards](../accounts/credit-cards.md)).

The words are plain on purpose: "I'll get" and "I'll give", "I gave money" and
"I took money", "late", "All paid".

## Behaviour
More → **Loans** (বাংলা: ধার ও বাকি).

- **Top**: "I'll get" (money people owe me) and "I'll give" (money I owe, and
  what is owed on credit cards), plus "N loans are late" when any is late. When
  both people and cards are in "I'll give", a small line splits it.
- **Three tabs**:
  - *I'll get*: the loans where I lent, late ones first, then by due day, then
    the newest.
  - *I'll give*: the credit cards at the top (a wallet card with what is owed,
    what is left to spend, the bill day and a **Pay bill** button), then the
    loans where I borrowed.
  - *People*: one row per person with what is left between us ("Owes you",
    "You owe", "Even", "All paid"), how many loans, and "Late". A tap opens the
    person.
- **A loan card**: person, "Owes you" / "You owe", what is left, a progress bar,
  "Paid ৳400.00 of ৳1,000.00" and when it is due ("Due 20 Oct", "Due today",
  "3 days late", "All paid"). "Show paid ones" brings the paid loans in (last).
- **Quick actions**: a long press opens a sheet (Add a payment, All paid, Send a
  reminder for money I will get, Edit, Delete). Swipe right to add a payment;
  swipe left to mark it All paid, which says "All paid." with an **Undo**.
- **One person**: a card with who owes whom and the difference, the loans with
  that person (open first, then "Paid"), **Add loan** (name filled in), **Send a
  reminder** (when they owe me) and **Set off** (see below).
- **New loan**: two big choices, *I gave money* ("They will pay me back") or
  *I took money* ("I will pay it back"); the name (one-tap chips for names used
  before); the amount; **Update my account too** (a switch: when on, the account
  shows as a wallet card with its balance now and "After this", and can be
  changed); and **More details** (closed at first): the date, the pay back date
  and a note.
- **One loan**: what is left ("left to get back" / "left to pay back"), the
  progress, the day it was lent or borrowed, the due day, the note, **Add a
  payment** (amount filled with what is left, a day, a note, the account as a
  card), **All paid**, **Send a reminder** (money I will get), a link to
  everything with that person when there is more than one loan, the payments
  (newest first, each can be deleted), edit and delete.
- **Reminders**: a notification at 9 am the day before and on the day a loan is
  due ("Rahim should pay you ৳500.00." / "You should pay Karim ৳300.00."). A
  loan that is late already is not reminded again; the list and Home show it.
  Saving a loan with a pay back date asks to allow notifications.
- **Send a reminder** opens the phone's share sheet with a friendly message
  ("Hi Rahim, a quick reminder about the ৳500.00 you owe me, which was due on
  1 Oct. Please send it when you can. Thanks!"). It is the amount left, or for
  a person what is left between us.
- **Home** shows a Loans card (what I'll get and give, a red line for late loans
  and for a card bill within 5 days). It is left out when there is nothing.

## Rules
- An amount is above zero. A due day is not before the day it was given. A name
  is required (at most 60 characters), a note at most 500.
- Two names are the same person when they match ignoring case and spaces
  ("Rahim" and " rahim ").
- A payment cannot be more than what is left. A loan is settled when nothing is
  left. Settled loans are not in the totals.
- **Everything can be edited** (name, kind, amount, day, due day, note, account),
  with two limits: the amount cannot go below what is paid, and the kind cannot
  change once something is paid (the payments went the other way). Payments
  keep their own balance changes.
- With an account, the balance moves through a transaction that is a
  *correction* (`is_adjustment`) in a **Loans** category: lending sends money
  out (expense type), borrowing brings it in (income type), a payment received
  brings it in, a payment made sends it out. Corrections are in the account
  balance but not in income, expense or budgets, so lending is not spending.
  The transaction list says "… · not in your totals".
- Editing a loan takes back the balance change it made and makes it again for
  the new values (the new account, amount, kind or day). A transaction the
  person deleted by hand stays deleted unless a different account is chosen. An
  archived account cannot be newly chosen; the one a loan uses already can stay.
- Deleting a payment or a loan also deletes the transactions it made, so the
  balances go back. Deleting such a transaction from the list does not stop the
  loan from being deleted.
- **Set off** (on a person who owes me and whom I owe): the same amount, the
  smaller of the two sides, is paid on the loans of both directions, earliest
  due first, with the note "Set off with Rahim". Only the difference is left. No
  account changes and no transactions. It asks first ("Then Rahim will owe you
  ৳700.00.") and says "Set off ৳300.00." with an **Undo**.
- The reminders of loans are set together with the recurring and card ones (see
  `reminder_sync.dart`); loan notification ids start at 100,000,000, card ones
  at 200,000,000. At most 60 loan reminders are kept.
- Backup format 4 holds loans (`debts`) and payments (`debtPayments`); older
  files still read. Restore replaces loans like the rest.

## Tests
- `test/features/debts/domain/debt_test.dart` (totals, people, set off,
  reminders)
- `test/features/debts/data/debts_repository_test.dart` (making, changing,
  setting off)
- `test/features/debts/data/debts_backup_test.dart`
- `test/features/debts/presentation/debts_screen_test.dart` (tabs, quick
  actions, people, set off, cards, the form, one loan, changing a loan)
- `test/features/debts/presentation/loans_home_card_test.dart`
- `test/features/reminders/reminder_sync_test.dart`
- `test/core/database/migration_test.dart`
- `test/features/transactions/presentation/small_screen_test.dart` (the loan
  and card screens at 360 dp, text x1.0 and x1.5)
