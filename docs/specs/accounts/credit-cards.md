# Credit cards

## Goal
A credit card is money I owe the bank, not money I have. It is its own kind of
account (separate from a debit card) so it can show what is owed, what can
still be spent, and when the bill is due, and so paying the bill is one tap.

## Behaviour
- **Kind**: *Credit card* (and *Debit card*, the old "Card"). A credit card has
  two extra, optional, fields: a **credit limit** and a **bill due day** (1 to
  31 of every month; in a shorter month the last day).
- **Form**: the opening balance becomes **Already owed on this card**: type what
  is owed as a plain number. It is saved as a balance below zero. Switching the
  kind of a form flips the sign of what was typed, so the money keeps its
  meaning. Saving sets the reminders.
- **Wallet card**: the right side says **Owed** with what is owed (not a
  negative number); "In credit" when more was paid than owed. With a limit there
  is a bar and "৳1,500.00 left to spend" next to "Limit ৳2,000.00", or "Over the
  limit by ৳500.00" in amber.
- **Spending**: a card is a normal account in the transaction form. The preview
  says **Owed after this**, and warns only when the purchase goes over the limit
  (owing is normal for a card). Spending counts as an expense when it happens.
- **Paying the bill** is a transfer into the card, so it is not an expense. In
  Loans, on the "I'll give" tab, each card shows the bill day ("Bill due 15 Oct",
  "Bill due today", "Bill due tomorrow") and **Pay bill**, which opens the add
  form as a transfer to the card for what is owed. The money comes from the
  default account (or the first other one) and can be changed. A card that owes
  nothing says "Nothing owed" and has no button; a card without a bill day says
  "Set a bill day to get reminders". Tapping a card opens its account.
- **Reminders**: for the next two bill days of each open card with a bill day, a
  notification at 9 am the day before and on the day ("Credit card bill due
  tomorrow" / "… due today", "Pay your Visa bill on time to avoid charges."). No
  amount is in it, since it changes with every purchase.
- **Home**: the Loans card counts what is owed on cards in "I'll give" and points
  out a bill due within 5 days.

## Dollars (dual currency cards)
A card such as EBL can show two limits, one in taka and one in dollars (for
example ৳111,200 and $74, after part of a ৳120,000 limit was moved to dollars).
The app keeps the balance in taka; dollars are written beside a taka amount,
never instead of it.
- **Card form**: *Credit limit* is the taka limit your bank shows (for a card
  with a dollar limit, the taka part only). *Limit in dollars* (optional) is the
  dollar limit. A short guide in the form says how to use the card.
- **Spending**: on a credit card account the add form shows a dollar field
  (*Spent in dollars* / *Refunded in dollars* / *Dollars this payment clears*).
  The amount field stays the taka the bank charged, so the card's balance is
  unchanged in kind. For an expense the form shows the rate it implies, and
  *Use today's rate* can fill the taka from the market rate.
- **Paying the bill** is a normal transfer from a taka account. *Pay bill*
  fills the dollars still due; change it to what this payment clears.
- **Under the card**, on the Accounts screen and in Loans ("I'll give"): the
  bill day, *Pay bill*, dollars spent this month, dollars still due, and what is
  left: `Left: X in taka and $Y in dollars`, and `About Z left in all` (the
  dollars at the latest rate, once there is one). On the wallet card itself a
  card with a dollar limit says `Limits X and $Y` instead of a bar.
- A transaction with dollars shows `$25.00` in its row.

## Rules
- Only a credit card keeps a limit and a bill day; another kind saves none. The
  limit is above zero; the bill day is 1 to 31.
- What is owed is the balance below zero: `owed = max(0, -balance)`;
  `available = limit - owed (+ credit)`. Archived cards and debit cards are not
  counted.
- The total balance counts a card like any account (what is owed lowers it),
  unless "Include in total balance" is off.
- Dollars: `due = max(0, spent - refunded - settled)` in US cents, where spent
  is dollar expenses on the card, refunded dollar income on it and settled the
  dollars of transfers into it. The two limits are separate pools:
  `usdLeft = usdLimit - due`; the dollars owed in taka are `due x rate`, where
  rate is taka per dollar on the latest dollar expense; with a dollar limit
  `takaOwed = owed - dollars owed in taka` (without one, dollars use the single
  limit and `takaOwed = owed`); `takaLeft = limit - takaOwed (+ credit)`;
  `totalLeft = takaLeft + usdLeft x rate`, known only with both limits and a
  rate. A limit is passed when `takaLeft < 0` or `usdLeft < 0`. The rate is the
  latest one, so the taka figures are close, not exact. Dollars are only
  accepted on a credit card (the card spent on, or paid into) and must be above
  zero; the dollar limit too.
- Schema version 7 adds `transactions.usd_amount` and `accounts.usd_limit`;
  backup format 5 saves both (older files read as none). CSV export gets a USD
  column.
- Schema version 6 adds `accounts.credit_limit` and `accounts.bill_due_day`;
  backup format 4 saves both (older files read as none). A spreadsheet import
  guesses *Credit card* from an account name with "credit" in it.

## Tests
- `test/features/accounts/domain/credit_card_test.dart`
- `test/features/accounts/data/credit_card_repository_test.dart` (saving,
  validation, spending and paying, backup)
- `test/features/accounts/presentation/credit_card_ui_test.dart` (the card, the
  form, spending)
- `test/features/accounts/domain/card_dollars_test.dart`
- `test/features/accounts/data/card_dollars_repository_test.dart` (saving,
  validation, the dollar totals, backup)
- `test/features/accounts/presentation/card_dollars_ui_test.dart` (the tile, the
  card on the accounts screen, the form)
- `test/features/debts/presentation/debts_screen_test.dart` (cards in Loans, Pay
  bill)
- `test/features/reminders/reminder_sync_test.dart`
- `test/core/database/migration_test.dart` (version 5 to 6, 6 to 7)
