# Add / edit transaction form

## Goal
Entering a transaction takes few taps and little room. The amount is a plain
number by default; the calculator is there when wanted.

## Behaviour
- Top: Expense / Income / Transfer.
- **Amount**: a large field typed on the system keyboard (numeric, decimal).
  New transactions start with the cursor in it. Next to it, a calculator button
  switches to the in-app keypad (`+ - × ÷`, backspace, hold to clear); the
  button then shows a keyboard icon to switch back.
- Leaving the calculator turns a sum into its result (`10+5` becomes `15`). If
  the sum cannot be worked out the calculator stays open with "Check the
  calculation first."
- While there is a sum, its result is shown under the field (`= ৳1,901.00`).
- The keyboard's "done" closes it and, for income and expense with no category
  yet, opens the category picker.
- **Category** (income / expense): one tile with the chosen category's path, or
  "Choose a category"; opens the [category picker](../categories/category-picker.md).
- **Account** (income / expense): a [wallet card](../accounts/wallet-cards.md)
  with its balance and "After this"; tap to choose another.
- **Transfer**: "From" and "To" wallet cards, a swap button between them, a
  fee field, no category. With nothing chosen the cards ask "Where does the
  money come from?" and "Where does the money go?".
- **Pay bill** (from Loans): the form opens as a transfer into a credit card for
  what it owes. See [credit cards](../accounts/credit-cards.md).
- A [credit card](../accounts/credit-cards.md) account says "Owed after this"
  and warns only when a purchase goes over its limit.
- Date: Today / Yesterday / Pick date. Note: free text.
- **Save** saves and closes. **Save & new** saves, then empties the amount,
  category and note and puts the cursor back in the amount, keeping the type,
  account and date, so several things bought the same day can be entered one
  after another. A line says "Saved ৳250.00. Add the next one."
- Editing shows "Save changes" only. Duplicating opens an add form with the
  details copied, dated today.

## Rules
- The amount field accepts digits (Bengali too) and one dot, two decimals, 12
  digits; commas and other characters are dropped (`sanitizeAmountText`).
- An amount that is empty, zero or negative is "Enter an amount."
- A category is required for income and expense, not allowed for a transfer.
- Nothing is cleared when saving fails.
- On a window shorter than 520 dp the whole form, keypad included, scrolls.
- A new category or account made from the form does not reset what was typed.

## Tests
- `test/features/transactions/presentation/transaction_form_screen_test.dart`
- `test/features/transactions/presentation/small_screen_test.dart`
- `test/features/transactions/presentation/transactions_screen_test.dart`
  (editing and duplicating)
- `test/features/transactions/domain/amount_calculator_test.dart`
  (`sanitizeAmountText`, `expressionHasOperator`)
- `test/features/transactions/presentation/amount_text_formatter_test.dart`
