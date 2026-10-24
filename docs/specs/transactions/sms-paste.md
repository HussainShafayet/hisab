# Paste an SMS

## Goal
bKash, Nagad, Rocket, Upay and the banks already send an SMS for every
payment. Copy it, tap one button, and the entry is written: amount, fee,
account, day, and the transaction id. No SMS permission, no package, nothing
leaves the phone: the person decides which message to copy.

## Behaviour
- On the add form (not when editing), an **SMS** button (message icon and the
  word) sits beside the quick line. It reads the clipboard.
- A message about money fills the form and a notice says *Filled in from the
  SMS. Check it and save.* The entry is never saved without the Save button.
  - **Received / Cash in / Add money / credited**: income (a cash in with a Cash
    account is a transfer from Cash).
  - **Cash out**: a *transfer* from the service account to Cash, with the
    **fee** in the transfer's fee (when both accounts exist; else an expense of
    amount + fee).
  - **Send money, payment, recharge, bill, debited**: an expense. A fee is
    added to the amount and the note says *{fee} fee included*. A recharge /
    bill tries the category of that name.
  - The **day** of the message is used when it is not in the future.
  - The **account**: the one whose name holds the service (bkash, nagad, rocket,
    upay). A message that does not name its service goes to the only mobile
    banking account (a bank debit: the only bank account), if there is just one;
    else the form keeps its account.
  - The **note** is `Cash out · 01712345678 · TrxID 9GH7K2L2`: what was done,
    with whom, and the id.
- **Same SMS twice**: if a note already holds the TrxID, nothing is filled and
  the form says *Already in your records: {amount} on {day}.*
- **Balance check**: when the SMS says the balance left, the notice adds either
  *The balance matches the SMS.* or *The SMS says X is left, the app would show
  Y. Something may be missing.* That catches the entries that were forgotten.
- Nothing copied: *Copy the bKash, Nagad or bank SMS first, then tap here.* Not
  a money message: *That does not look like a message about money. Copy the
  whole SMS and try again.*

## Rules
- `parseSms` (`transactions/domain/sms_entry.dart`) is pure. The messages are not
  all alike, so it does not expect one layout. It finds the money figures
  (`Tk`, `BDT`, `৳`, `Taka`, before or after the number) and labels each by the
  words just before it: *fee* / *charge*, *balance* / *limit*, else the amount.
  The kind comes from words (cash out, cash in, received, credited, recharge,
  bill, send money, payment, debited...). The TrxID, a phone number or shop,
  the service name and a `dd/mm/yyyy` or `24-OCT-26` date are read the same way.
  No amount or no kind: not a money message.
- `planSms` (`transactions/domain/sms_plan.dart`) decides type, accounts, amount
  and the balance to compare.
- The TrxID lives in the note, so it is searchable, travels in backups and CSV,
  and needs no new column. The look-up is `NoteQueries.entryWithNote`.
- One message at a time; if several are copied, the first is read.

## Tests
`test/features/transactions/domain/sms_entry_test.dart`, `sms_plan_test.dart`,
`test/features/transactions/presentation/sms_paste_test.dart`.
