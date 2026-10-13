# Safe to spend today

## Goal
Answer "how much can I spend today?" on Home, from the month's budget, what is
already spent and the bills still to come.

## Behaviour
- A card under the wallet strip on Home.
  - With an overall budget: *You can spend today* and the amount left of
    today's share, a bar of how much of today's share is spent, `share a day -
    spent today`, and a note: `X of the budget is left for N days, after B of
    bills still to come.` (the bills part only when there are bills).
  - Today's share spent: *Over today's share* and by how much, in red.
  - Budget used up (counting the bills): *Over the budget, counting the bills to
    come* and by how much, in red.
  - Without an overall budget: a prompt with a *Set budget* button to the Budget
    tab.

## Rules
- `spentBeforeToday = spentThisMonth - spentToday` (transfers and balance
  adjustments are not spending, as everywhere).
- `upcomingBills` = for each active recurring **expense**, every day from its
  next due day to the end of this month (a day due and not yet added counts;
  paused, ended and income rules do not).
- `remaining = budget - spentBeforeToday - upcomingBills`;
  `daysLeft = days in month - day + 1` (today included);
  `perDay = remaining ~/ daysLeft` (0 when `remaining <= 0`);
  `leftToday = perDay - spentToday`.
- Credit card bills are not added: the spending was counted when it was made.

## Tests
- `test/features/budget/domain/safe_to_spend_test.dart`
- `test/features/dashboard/presentation/safe_to_spend_card_test.dart`
