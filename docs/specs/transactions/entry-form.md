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

## Smaller and easier (keypad first)
Design: the canvas "Hishab add transaction redesign" (artboards 4 and 5).

- **Keypad first.** Typing the amount with the calculator keypad is the
  default (Settings > Type the amount with, still switchable to the keyboard,
  and the button beside the amount switches while typing). A new entry opens
  with the keypad on screen.
- **The keypad makes room.** Choosing a category (from the grid or the list),
  an account or the date puts the keypad away so the note, *More details* and
  Save are in view. A small *Edit* button beside the amount, or a tap on the
  amount, brings it back. Editing an existing entry starts with it away.
- **Quick categories.** While no category is chosen and some are used often
  (last three months, `frequentIdsFor`), a 4-column grid shows them with an
  *All* tile (`category-field`) that opens the full list; one tap chooses. Once
  a category is chosen, or when nothing was used yet, the single category tile
  is shown as before.
- **Slimmer account cards** (`AccountCard(compact: true)`): less padding, no
  account kind under the name; the balance and *After this* lines are the same.
- **More details.** The trip or event and the feeling are folded under a
  *More details* button (it opens by itself when the entry already has one of
  them). On a new transfer the same button holds the *Fee*; there is no button
  when editing a transfer (the fee is only for new ones). The dollars of a
  credit card stay out in the open, since they only appear when they matter.
- **Transfer.** From and To are two slim cards one above the other, each as
  wide as the screen (name and balance beside each other), with the swap
  button (`swap-accounts`) in a row of its own between them, on a thin line.
  (They were side by side before, with the button laid over the middle: it
  covered part of both cards and left each a small area to tap.) A card not
  chosen yet is a tile that says *From* or *To*.
- A chosen category shows *Change* beside it (the tile opens the list).

Tests: `transaction_form_screen_test.dart` (groups *the amount*, *the keypad
and the quick categories*, *more details*), `feeling_ui_test.dart`,
`tags_ui_test.dart`, `settings_screen_test.dart` (calculator by default).
Test helpers: `typeAmount` presses keypad keys when the keypad is the entry
mode, `turnKeyboardOn`, `turnCalculatorOn`, `openMoreDetails`.

## Deleting from the list
- A row swiped to the left, past 60% of its width (a longer swipe than for
  editing), is deleted at once, with no question. A snack bar says
  *Transaction deleted* with **Undo**, which stays for 8 seconds
  (`undoDuration`, also for the other Undo bars: accounts, categories, loans,
  bazar). Undo puts the transaction back as it was.
- A swipe to the right, or a tap, opens the editor. A long press has Edit,
  Duplicate and Delete.
