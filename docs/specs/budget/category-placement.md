# Where a category budget sits

Phone feedback (2026-11-05): category budgets looked wrong. Two budgets could
both read "Gifts" (one under *In-laws*, one under *Brothers & sisters*), and a
budget for *Family & gifts* also counts everything inside it, so the same
spending showed in two cards and the cards did not add up.

- Each category budget card shows the path of the categories it sits inside
  (`Family & gifts › In-laws`) under its name; a top-level one shows nothing.
- When a category above it has its own budget this month, the card says
  *Also counted in the {name} budget* (the nearest such one).
- What is spent is unchanged: a category budget counts the category and
  everything inside it, at any depth (`BudgetsDao._selectWithSpent`).
- Logic: `budgetPlacement` in `lib/features/budget/domain/budget_placement.dart`;
  tests in `test/features/budget/domain/budget_placement_test.dart`.

## Follow-up (same day)

- When the budgets right inside a category budget add up to more than its
  limit, the card warns in red: *The budgets inside add up to {amount}, more
  than this one* (`budgetPlacements`, `BudgetPlacement.insideLimits`).
- Each category card has a list button (`budget-entries-<categoryId>`) that
  opens a sheet with the month's expenses of the category and everything
  inside it (no transfers or balance fixes), with the total; a row opens the
  transaction (`budgetEntries` in `budget_entries_sheet.dart`).
