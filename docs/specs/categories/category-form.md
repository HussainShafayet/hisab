# Add / edit category

## Goal
Making a category is visual and quick, and putting it inside another category
is a choice from a list, not a guess.

## Behaviour
- A preview at the top: the icon on its color, the name as typed ("Category
  name" until then) and where it is ("Expense · top level" or "Inside Food ›
  Groceries").
- **Name**; **Expense / Income** (fixed once the category exists, because old
  transactions depend on it).
- **Inside**: a field that opens a sheet with the places the category can go,
  as a tree with search, and "Top level" as the first row. The sheet has no
  "New category" button. Where it is now is checked.
- **Icon** and **Color** pickers.
- The Add category / Save changes button is pinned below the form.
- "Add sub-category" from the list opens the form with Inside already set and
  the parent's icon and color. A category saved from here returns its id, so
  the transaction form can choose it at once.

## Rules
- The places offered are `categoryParentProblem(...) == null`: not itself or
  anything inside it, same type, not archived, within five levels. The current
  parent stays offered even if it was archived since.
- Switching the type forgets the chosen place.

## Tests
- `test/features/categories/presentation/categories_screen_test.dart`
  (groups "adding a category", "editing a category", "categories inside
  categories", "the category form")
- `test/features/transactions/presentation/small_screen_test.dart`
