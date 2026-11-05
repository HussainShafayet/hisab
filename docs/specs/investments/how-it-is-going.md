# Investments: how long, how fast, and the list

Phone feedback (2026-11-05): "investment eo same" (the same: more info and a better
UI).

## Behaviour
- **A facts card on the investment page** (`investment-facts`), under the
  summary:
  - *Held for 6 months* (or days, below 60). A closed investment stops at its
    last line.
  - A bar and *18% of the money put in is back.* (profit and money taken back
    against what was put in), or *All the money put in is back.* from 100%.
  - *About 39% a year at this pace.* (or *lost*): the return divided by the money
    put in, scaled to a year from the days held. Only after 30 days.
  - *Profit is about ৳300.00 a month.* (profit received divided by the months
    held; only with some profit and 30 days).
  - *All the money is back in about 28 more months.* at that pace, while some of
    the money is not yet back.
  - *Profit by month*: a bar for each of the last 12 months (`profit-bar-YYYY-MM`),
    shown when there was any profit.
- **The list**: *All · 3*, *Open · 2*, *Closed · 1* chips (`inv-all`, `inv-open`,
  `inv-closed`), a sort button (`investment-sort`: newest, best return, most
  put in), a line *Best so far: Shop, 50%* (`investment-best`, with two or more
  investments and a gain), and how long each has been going after *Put in ৳X*.

## Rules
- `factsOf` (`investment_facts.dart`): recovered = (profit + taken back) / put in;
  yearly rate = return * 365 / (put in * days held); profit a month = profit * 30 /
  days held; months to payback = (put in - profit - taken back) / profit a month,
  rounded up.
- `profitByMonth` gives twelve months oldest first, zero where nothing came.
- `arrangeInvestments` filters and sorts; ties keep the newest first.

## Tests
`test/features/investments/domain/investment_facts_test.dart`,
`test/features/investments/presentation/investment_facts_ui_test.dart`.
