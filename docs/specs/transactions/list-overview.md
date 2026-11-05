# Transaction list overview and balance by kind

Phone feedback (2026-11-05): "transaction route ta aro improve, onek info dekhano,
smooth and clear UI" and "transaction er somoy type wise current balance ta show
korle kemon hobe?".

## Behaviour: the list (Transactions tab)
- **Type chips** under the month switcher (`type-all`, `type-expense`,
  `type-income`, `type-transfer`): *All · 4*, *Expense · 2*... One tap narrows
  the list to that kind. The counts are for the list with everything else (month,
  search, other filters) applied but the type, so a chip says what a tap would
  show. They set the same type filter as the filter sheet (`withType`).
- **Facts line** under the summary card: *N entries*, *৳X a day* (what was
  spent divided by the days of the month so far), *Biggest ৳Y* and *Most on
  {category}*. It follows the filters. Balance fixes and transfers are never
  spending. (`statsOf` in `transaction_stats.dart`; `stat-count`, `stat-per-day`,
  `stat-biggest`, `stat-top`.)
- **Where a category sits**: a row whose category is inside another shows
  `Food › Kacha bazar` first in its second line (`categoryPath`), so *Fish*
  and a *Fish* somewhere else can be told apart.
- Time of day under each amount (see entry-form).

## Behaviour: the form
- Under the account card (and under From / To for a transfer) a strip
  (`type-balances`) shows what each **kind** of account holds right now: *Cash
  ৳5,000.00*, *Mobile banking ৳1,200.00*, *Bank ৳30,000.00*, *Credit card -৳4,000*
  (owed, in red). The kinds used by this transaction have a colored border.
  Archived accounts are left out. (`balancesByType`, `TypeBalanceStrip`.)
- The wallet cards keep showing the balance and *After this* of the chosen
  account.

## Tests
`test/features/transactions/domain/transaction_stats_test.dart`,
`test/features/transactions/presentation/transactions_overview_test.dart`,
`test/features/accounts/domain/type_balances_test.dart`.
