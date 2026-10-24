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
- Where: the income and the balance of the period on Home, the Transactions tab
  and Reports (the balance would give the income away); each income row in the
  lists (Home's Recent, Transactions, trips, reports); the income next to a day
  in the Transactions list; the income line of *Compared with last month*
  (shows only the percent, not the amount).
- **Tap** the dots and every hidden income shows for 5 seconds, then hides
  again.
- Not covered: account balances (use *Hide balances on Home*, which is
  separate and should be on too, since a balance can give the income away),
  Month wrapped, the income-by-category chart, an income opened for editing.

## Rules
- Preference `hide_income` (`AppPreferences.hideIncome`).
  `incomeHiddenProvider` is true while the preference is on and the person has
  not just tapped (`incomeRevealProvider`, a 5 second timer).
- `HiddenIncome` widget (`settings/presentation/widgets/hidden_income.dart`)
  draws the dots and the bar; `spentShare` is expense / income, no bar when
  there is no income.

## Tests
`test/features/settings/presentation/hide_income_test.dart`.
