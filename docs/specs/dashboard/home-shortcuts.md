# Loans up front (Home shortcuts)

## Goal
Loans (dhar / baki) and credit card bills were two taps away under More. They
are now one tap from Home, and Home says so when there are none yet.

## Behaviour
- **Shortcut row** on Home, under the wallet strip: Loans, Bazar list, Split a
  bill, Savings goals. The Loans button has a red dot while a loan is late.
- **Loans card** moved up, right under *Safe to spend today*, and has an
  *Add loan* button.
- With no loans and no card bill, Home shows a small *Loans* card that says
  what it is for and has an *Add loan* button (it used to be hidden).
- **More** lists Loans second, right after Accounts.

## Rules
- The red dot is `debtTotals(...).overdueCount > 0`, the same rule as the
  *N loans are late* line of the Loans card.
- Nothing here changes how loans work; only where they are reached from.

## Tests
- `test/features/dashboard/presentation/home_shortcuts_test.dart`
- `test/features/debts/presentation/loans_home_card_test.dart` (the card itself)
