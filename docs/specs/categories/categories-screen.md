# Categories screen

## Goal
See all categories as the tree they are, and keep it tidy.

## Behaviour
- Expense / Income switch at the top, then a **Show archived** chip (words, not
  an eye icon: archived categories are hidden, not deleted, and the chip brings
  them back greyed so they can be restored).
- The tree: every category on a row with its icon, name and, when it has
  others inside, how many ("2 sub-categories"). Rows are indented by depth.
- A category with others inside has an arrow that closes and opens it; closing
  hides everything inside it, at any depth. Everything starts open. An app bar
  button closes or opens all (shown only when something is nested).
- Tap a row to edit it. The three dots: Edit, Add sub-category (while there is
  room under the five-level limit), Archive / Restore.
- Archiving a category hides everything inside it and can be undone; a
  sub-category cannot be restored while something above it is archived.
- With no categories: an empty state with an Add category button.

## Rules
- Closed state is kept while the screen is open, not saved.
- "Add sub-category" is not offered on a level-4 category (a level-5 one would
  be the last): `depth + 2 <= maxCategoryDepth`.
- See [Categories inside categories](multi-level-categories.md) for nesting.

## Tests
- `test/features/categories/presentation/categories_screen_test.dart`
- `test/features/transactions/presentation/small_screen_test.dart` - five
  levels of long names at 360 dp, text x1.0 and x1.5.
