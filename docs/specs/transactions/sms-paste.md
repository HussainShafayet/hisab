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
  - The **account** (M25 order): 1. the service named in the SMS (also in Bangla:
  বিকাশ, নগদ, রকেট, উপায়); 2. the account the person ended with last time for
  the same kind of SMS (`SmsEntry.source`: the service, `ac1234` for a bank A/C,
  or `id-trxid` for the id label style; stored in `app_settings` as
  `sms_account:<source>` by `sms_memory.dart` when the entry is saved);
  3. an account whose name has the A/C digits (*City Bank 1234*); 4. the only
  account of the kind. Older rule: the one whose name holds the service (bkash, nagad, rocket,
    upay). A message that does not name its service goes to the only mobile
    banking account (a bank debit: the only bank account), if there is just one;
    else the form keeps its account.
  - The **note** is `Cash out · 01712345678 · TrxID 9GH7K2L2`: what was done,
    with whom, and the id.
- **Same SMS twice**: if a note already holds the TrxID, nothing is filled and
  a dialog (*Already added*, key `sms-already-added`) shows that entry with
  *Open it* and *Cancel*.
- **Looks added already** (M25): an SMS with no id (a bank's), or whose note was
  edited, is compared with the entries of its day: same type, amount and
  account (`sameEntryAs`). A dialog (*Maybe already added*) offers *Open it*,
  *Add anyway* (`sms-add-anyway`) or *Cancel*.
- **What was read** (M25): the notice says *Read from the SMS: {type} of
  {amount}.* and then the account: *Account: {name}.* when it is sure (named,
  remembered or matched by the A/C digits), *... your only one of this kind.
  Check it.* when it only guessed, or *The SMS does not say which account.
  Choose the account below.*
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

- Reading (M25): Bangla digits are turned into digits; Bangla words (পেয়েছেন,
  পাঠিয়েছেন, ক্যাশ আউট, রিচার্জ, বিল, কাটা হয়েছে, ফি, ব্যালেন্স, টাকা),
  *Cash-Out*, *deducted*, *debit*, *withdrawn*, *top up*, *salary* and figures
  with only a label (*Fee: 5.00*, *Balance: 900*) are understood. *credit card*
  is not *credited*. An ATM withdrawal (or any message with an A/C, card or
  bank word) is a bank message: it goes to the only bank account.

## Tests
`test/features/transactions/domain/sms_entry_test.dart`, `sms_plan_test.dart`,
`test/features/transactions/presentation/sms_paste_test.dart`.
