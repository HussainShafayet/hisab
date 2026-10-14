# Can I afford it?

## Goal
Answer the question people ask before a purchase, from what Hishab already
knows: today's safe amount, the month's budget and the money in the accounts.

## Behaviour
- The *Safe to spend today* card on Home has a **Can I afford it?** button. It
  opens a sheet with a *Price* field; as the price is typed, a card says:
  - *Yes, go ahead. You will still have X to spend today.* (it fits today's share)
  - *You can, but it uses up N days of your daily share. After it, about X a
    day.* (the month stays inside the budget)
  - *It goes over this month's budget by X. Sleep on it?*
  - *That is X more than the money in your accounts.*
  - with no budget set: *Your accounts can pay for it. X would be left.*
- Nothing is saved or added; it is only a check.

## Rules
- `affordCheck` (`budget/domain/afford.dart`), first match wins:
  1. `price > totalBalance` -> over the accounts by `price - balance`.
  2. no budget -> fits the accounts, `balance - price` left.
  3. `remaining - price < 0` -> over the budget by `price - max(0, remaining)`.
  4. `price <= leftToday` -> fits today, `leftToday - price` left.
  5. otherwise it eats `ceil(price / perDay)` days (all the days left when the
     share is under a poisha) and the new share is `(remaining - price) /
     daysLeft`.
- `remaining`, `perDay` and `leftToday` are those of *Safe to spend today*;
  `totalBalance` is the Home total (accounts that count).

## Tests
- `test/features/budget/domain/afford_test.dart`
- `test/features/dashboard/presentation/afford_ui_test.dart`
