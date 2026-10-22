# Merging two categories

## Goal
After an import, or after years of typing, two categories mean one thing
("Rickshaw" and "Bus & rickshaw"). Moving the transactions one by one is not
an option, so a category can be folded into another.

## Behaviour
- The menu of an active category on the Categories screen has **Merge into…**
  (an archived category has *Restore* only).
- A category with sub-categories in use is explained at once (*"Food" has
  sub-categories. Move or merge them first.*): nothing opens. Sub-categories
  that are all archived do not count.
- Otherwise the category picker opens, with the active categories of the same
  type except itself, and no *Add*. After a pick, a question: *Merge "A" into
  "B"?*, saying what moves (transactions, budgets, repeating entries and
  challenges), that A is archived afterwards, and that it cannot be undone
  here (a backup can bring it back).
- After **Merge**: *N transactions moved to B*. A is archived, so it is gone
  from the lists and pickers, and it comes back with *Show archived* and
  *Restore* if it was a mistake (the things moved do not move back).

## Rules (`CategoriesRepository.mergeCategory`)
- One database transaction: all or nothing.
- Refused: into itself, into the other type, into an archived category, from
  or into a category that is not there, from a category with active
  sub-categories.
- Moves: `transactions.category_id`, `recurring_rules.category_id`,
  `challenges.category_id`; budgets: for each month of A's budgets, B's budget
  of the same month gets A's amount added, or, when B has none, the budget
  changes category. The result says how many of each.
- The balance and the account of nothing change; the totals of the reports
  follow the new category.

## Tests
- `test/features/categories/data/merge_category_test.dart`
- `test/features/categories/presentation/categories_screen_test.dart` (group
  *merging*)
