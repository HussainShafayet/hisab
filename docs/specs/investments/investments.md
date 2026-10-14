# Business investments

## Goal
Track the money put into a business or another venture (a shop, a farm, a
partnership): how much went in, what came back as profit, what is still in it
and what it is worth, so the answer to "is it paying?" is one number.

## Behaviour
- **More > Investments** lists them with a summary on top: the return so far
  (with the percent of the money put in), money put in, profit received and
  what it is worth now. Each investment shows its own return and percent, green
  for a gain, red for a loss. An empty list invites the first one.
- **New investment**: a name, an optional note (who you are in it with) and the
  start day. It opens straight on its page to add money.
- **The page** shows the return, the sums (put in, taken back, still in, profit
  received, worth now) and three buttons: **Put money in**, **Got profit**,
  **Took money back**, plus **Update value**. Every line is listed newest first
  with its day, account and note, and can be removed (after asking). The menu
  edits, closes or opens again, or deletes the investment.
- Each line can name an **account**. Then that account's balance moves too:
  money put in leaves it, profit and money taken back arrive in it. "Only record
  it" leaves the accounts alone.
- **Home** has an Investments card (put in, return and percent) when there is at
  least one investment; tapping opens the list.
- Backup and restore carry the investments and their lines (format 11).

## Rules
- Three kinds of line, all above zero:
  - *put in*: leaves the account as an **expense correction** (category
    "Investments"), so it is not spending;
  - *take back*: arrives as an **income correction** (same category), so it is
    not income, and it cannot be more than what is still in it (put in less
    taken back): money above that is profit and is refused with a hint;
  - *profit*: arrives as **real income** (category "Investment profit"), so it
    counts in the month's income and in Reports.
- **Still in** = put in - taken back (never below zero).
- **Worth now** = 0 once the investment is closed, else the value the person set,
  else **still in** (at cost). Clearing the value goes back to cost.
- **Return** = profit received + taken back + worth now - put in; below zero is
  a loss. **Percent** = return / put in, rounded half away from zero; none when
  nothing was put in. With no value set, the return is just the profit.
- A **closed** investment is over: what was not taken back counts as lost. It
  takes no more money in; profit and money taken back can still be recorded.
- Deleting a line or an investment removes the transactions they made.
- Totals on the list and Home add up the investments the same way.

## Tests
- `test/features/investments/domain/investment_test.dart`
- `test/features/investments/data/investments_repository_test.dart`
- `test/features/investments/data/investments_backup_test.dart`
- `test/features/investments/presentation/investments_ui_test.dart`
- `test/core/database/migration_test.dart` (schema 13)
