# Plan, projection and spending with no budget

Phone feedback (2026-11-05): "budget route tao aro UI soho aro info diye improve
kora jay".

## Behaviour (Budget tab)
- **Projection** under the monthly budget (`overall-projection`): *At this pace
  you will spend ৳X, ৳Y over the budget* (red) or *..., within the budget*. The
  pace is the spending so far divided by the days gone, carried to the end of
  the month (`projectedSpend`). Nothing in the first two days of the month (one
  big bill would make the guess silly), before the month, or for a month that is
  over.
- **Planned in categories** (`budget-plan`, shown when there is a monthly budget
  and at least one category budget): a bar and *৳A of ৳B is planned*, then
  *৳C is not planned yet* or, in red, *The categories ask for ৳C more than the
  month.* A category budget inside another one (Fish inside Food) is part of it
  and is not counted twice (`allocationOf`, `BudgetPlacement.countedInId`).
- **Spent with no budget** (`budget-unbudgeted`): the month's expenses in no
  budgeted category (nor inside one), as a total and the three biggest top-level
  categories, each with *Set budget* (`set-budget-<id>`) that opens *Add category
  budget* with that category chosen. Expenses with no category are listed as
  *No category* without a button. Transfers and balance fixes never count
  (`unbudgetedSpending`).

## Tests
`test/features/budget/domain/budget_insights_test.dart`,
`test/features/budget/presentation/budget_insights_ui_test.dart`.
