# Split a bill

## Goal
When you pay a bill for friends (lunch, a taxi, tickets), record it in one go:
your part is your spending, and each friend's part is money they owe you.

## Behaviour
- **More > Split a bill**, or the split icon on the Loans screen.
- Fields: what it was for (optional), the bill total, the account it was paid
  from (the first one until another is chosen), the category of your part (an
  expense category) and the day (up to today).
- **Split with**: type a friend's name and add it, or tap a suggestion (people
  from your loans). Each friend gets a *Part* field, filled with the equal share
  while no part was typed by hand. Changing a part switches to hand-made parts;
  *Split equally* goes back. A friend can be removed.
- *Your part: X* shows what is left of the bill; red text says when the parts
  add up to more than the bill.
- **Save split**: your part becomes an expense (note `Lunch (my part of
  1,200.00)`), each friend gets a loan to them (they owe you) for their part
  with the same account. A snack bar says what your part was.

## Rules
- Equal share = `total ~/ (friends + 1)` for each friend; your part is the rest,
  so a poisha that does not divide stays with you.
- The bill is above zero; 1 to 20 friends, each with a name, each once
  (whatever the case) and a part above zero; the parts do not exceed the bill.
  Your part may be 0 (then there is no expense).
- The account loses the whole bill. Loans move the balance through balance
  adjustments, so budgets and reports count only your part.
- Saved together or not at all.

## Tests
- `test/features/debts/domain/split_test.dart`
- `test/features/debts/data/bill_splitter_test.dart`
- `test/features/debts/presentation/split_bill_screen_test.dart`
