# A tidier Home

## Goal
Home has a lot on it. It should keep all of it and still read at a glance:
the money first, what needs doing next, the rest further down.

## Behaviour
- **The order**, top to bottom:
  1. *Total balance* and the *wallets*;
  2. what needs the person, each only when there is something: an account
     below zero (*Overdrawn*), a bill that is due, the *Time to back up* card,
     the welcome card of a new install, *Month wrapped* at the turn of the
     month;
  3. the shortcuts (Loans, Bazar list, Split a bill, Savings goals);
  4. *You can spend today*;
  5. **This month**: income, expense and balance; the budget ring; today and
     this week;
  6. **Plans and loans**: Loans (always, with its own empty state), a
     challenge that runs, investments, the next festival fund;
  7. **Top spending** and **Recent**;
  8. **Habits, tips and fun**: a bar that is closed until it is tapped (it
     says *Your streak, how the month felt, tips*). Open, it holds Takka the
     coin, the streak card, the regret meter and the insights.
- The bar remembers its state (`home_more_open` in the app settings, off by
  default; it travels in a backup like the other settings).
- Before this, Takka, the streak, the backup card and the wrapped card were
  above the total balance, so the balance was nearly a screen down.
- Each card still hides by itself when it has nothing to say.

## Tests
- `test/features/dashboard/presentation/home_layout_test.dart`
- `test/features/settings/domain/app_preferences_test.dart`
