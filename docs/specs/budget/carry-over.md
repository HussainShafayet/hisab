# Carry over what is left

## Goal
A month with money left in a budget should not lose it. With carrying over on,
what was not spent in a month is added to the same budget of the next month
(Eid and the other months that cost more are the reason).

## Behaviour
- The Budget tab has a switch, **Carry over what is left** (off by default),
  under the overall budget. It is saved as the preference `budget_rollover`.
- With it on, a budget that got something from before shows *Includes ৳X left
  over from last month* under *Spent ... of ...*, on the overall card and on
  a category's card. The limit shown and used everywhere (progress, the *left*
  figure, Home's *Safe to spend*, the budget alerts, the insights) is the set
  amount plus that.
- Editing a budget starts from the amount that was **set**, not the total:
  `BudgetItem.setAmount = limit - carriedOver`.
- While carrying over is on, the edit box of a budget (overall or a category)
  has **Do not carry over this budget**: it then takes nothing from the months
  before and passes nothing on (`budgets.no_carry`, schema 16). It is kept when
  the amount is changed and when last month's budget is copied.
- While it is **off**, and last month's overall budget had something left, the
  line under the switch says *Last month ৳X was left. Switch on to add it to
  this month.* (`BudgetsRepository.leftoverLastMonth`: that month's set amount
  less its spending, whatever the switch says.)

## Rules
- A month leaves `limit - spent` when that is above zero, where `limit` is its
  set amount plus what it got itself. Overspending leaves nothing and takes
  nothing off the next month.
- It goes on month after month, so a leftover can pass through many months,
  but only the last 12 months count (`rolloverMonths`).
- A month that does not have that budget, or has it set to carry nothing,
  breaks the chain: the next month starts again from zero. The overall budget and each category budget carry
  on their own.
- Nothing is saved: the carried amount is worked out each time
  (`BudgetsRepository._carriedInto`), so changing a past month's budget or
  entries changes it.
- Copying last month's budget copies the amounts that were set, without what
  was carried.
- Switching it on or off updates the Budget tab, Home and the insights.
- The switch is a setting, so a backup holds it with the others (format 13);
  the flag of a single budget is in the budgets of the backup (`noCarry`).

## Tests
- `test/features/budget/data/budgets_repository_test.dart` (carrying over)
- `test/features/budget/presentation/budget_screen_test.dart` (carrying over)
- `test/features/settings/domain/app_preferences_test.dart`
