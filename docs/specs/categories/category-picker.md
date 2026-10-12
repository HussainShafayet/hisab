# Category picker

## Goal
Choosing a category should be quick whether there are 10 categories or 100:
search, the ones used most, and the tree.

## Behaviour
- Opened from the "Expense category" / "Income category" field of the
  transaction form. A bottom sheet, 92% of the height, lifted above the
  keyboard.
- Search field on top. Typing filters the whole tree to the categories whose
  path contains the text (case-insensitive), as a flat list with the path
  under each name. Searching "food" therefore also lists what is inside Food.
- "Frequently used": up to six categories used most in the last 90 days, as
  chips. Hidden while searching and when nothing was used.
- "All categories": the tree. Categories with others inside have an arrow
  that opens and closes them; the ancestors of the chosen category start open.
  Tapping a row chooses that category (a parent can be chosen too).
- The chosen category has a check. An archived one (when editing an old
  transaction) shows "(archived)".
- "New category" at the bottom opens the new-category form. When it is saved
  the new category is chosen and what was typed in the transaction is kept.
- No match: "No category matches "xyz"." with an "Add category" button. No
  categories at all: "There are no categories yet." with the same button.

## Choosing where a category goes
The same sheet is used for the "Inside" field of the category form
(`topLevelLabel` set, `allowAdd` false): a first row "Top level (not inside
another)", no "New category" button, and only the categories the category can
go inside. With none: "There is no other category to put it inside yet."

## Rules
- Only categories of the transaction's type are listed.
- Quick picks that share a name with another category show the whole path.
- The form shows the whole path of the chosen category (`Food › Groceries`).
- Changing the type (expense/income) clears the chosen category.

## Tests
- `test/features/transactions/presentation/transaction_form_screen_test.dart`
  (group "choosing a category").
- `test/features/transactions/presentation/small_screen_test.dart` - the picker
  at 360 dp wide, text x1.0 and x1.5, with long names.
- `test/features/transactions/data/transactions_repository_test.dart` - tree
  order and the frequent ids in the form options.
