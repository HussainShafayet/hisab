# How it felt, and the regret meter

## Goal
Make people look at their spending without a lecture: mark an expense as
Needed, Wanted or Regret, and see on Home how the month felt.

## Behaviour
- **Add / edit an expense** has three chips under the trip or event:
  *How did it feel? (optional)* - **Needed**, **Wanted**, **Regret**. Tapping the
  chosen one again clears it. Income and transfers have no chips.
- A regretted expense says *Regret* in its list line.
- **Home**, under the spending tiles: *How your spending felt*, a bar of the
  month split into the three, their amounts, what Takka says, and *N days
  since your last regret*. The card is not there until something is marked
  this month.

## Rules
- Stored in `transactions.feeling` (`need` / `want` / `regret`, nullable), schema
  v12; the repository keeps it only on an expense. Backup format 10 (`feeling`
  on a transaction; older files have none). It is not in the CSV export.
- Totals use `FeelingQueries` (`feeling_queries.dart`): expenses only, no balance
  adjustments, `start <= date < end` of the current month; the last regret and
  the count of marked expenses are over all time (local day).
- Takka's line: no regret -> *No regrets this month. Takka is proud!*; regret
  of 30% or more of the marked money -> *A lot of regret...*; otherwise it
  names the amount.

## Tests
- `test/features/transactions/domain/feeling_summary_test.dart`
- `test/features/transactions/data/feeling_test.dart` (saving, totals, backup)
- `test/features/transactions/presentation/feeling_ui_test.dart` (chips, Home)
- `test/core/database/migration_test.dart`
