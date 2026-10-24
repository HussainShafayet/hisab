# Hide income

## Goal
Phones are shown around: at the bazar, in the office, to family. Income is the
number most people want to keep to themselves. With **Hide income** on, the
income is not on screen, but its meaning is still there for the owner.

## Behaviour
- Settings > Privacy: **Hide income** switch (off by default; travels in
  backups like the other settings).
- While on, income shows as `৳ ••••` and, in the summaries, a small bar under
  it: how much of the income is spent. Green up to 80%, orange up to 100%, red
  above. The bar means something to the owner and nothing to anyone looking.
- Where: **every income amount**.
  - Lists: each income row (Home's Recent, Transactions, search, trips, bulk
    edit), the income next to a day in the Transactions list, a trip's
    *Received*, a repeating entry that is income (the list and Home's due card).
  - Summaries: the income and the balance of the period on Home, the
    Transactions tab and Reports (the balance would give the income away); the
    income line of *Compared with last month* shows only the percent.
  - Reports: *Kept X% of income* is left out (with the expense it would give the
    income away); the *Income* choice of *Spending by category* and *Where the
    money went* is not offered; *Income vs expense* shows spending only
    (*Spending by month*); *By account* shows dots for the income of an
    account; *Month by month* (year view) shows spending only, the average
    month is the expense, and *Most kept* is left out.
  - Month wrapped: the card of money in and out says only what was spent.
- The bar (how much of the income is spent) is on the Income and Balance cells of
  the summaries. A person who can read the bar and also sees the expense could
  work the income out, so the bar is a hint for the owner, not a lock.
- **Tap** the dots and every hidden income shows for 5 seconds, then hides
  again.
- Not covered: an income opened for editing (the owner is editing it), and the
  balance of an account: *Hide balances* is separate (Home and Accounts), and
  should be on too, since a balance can give the income away.

## Rules
- Preference `hide_income` (`AppPreferences.hideIncome`).
  `incomeHiddenProvider` is true while the preference is on and the person has
  not just tapped (`incomeRevealProvider`, a 5 second timer).
- `HiddenIncome` widget (`settings/presentation/widgets/hidden_income.dart`)
  draws the dots and the bar; `spentShare` is expense / income, no bar when
  there is no income.

## Tests
`test/features/settings/presentation/hide_income_test.dart`.
