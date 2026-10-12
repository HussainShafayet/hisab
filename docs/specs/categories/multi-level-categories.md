# Categories inside categories

## Goal
Real spending has more than two layers (Food > Restaurant > Dinner). A
category can be put inside any other category of the same type, up to five
levels in all.

## Behaviour
- Categories screen: a tree, each level indented further. "Add sub-category" is
  offered on every category that still has room for one more level.
- Category form: "Parent category" lists, in tree order and with the whole path
  (`Food › Groceries`), every category the one being edited may go inside.
  A category that has others inside can be moved too, and takes them along.
- Archiving a category hides everything inside it; restoring it brings all of
  that back. A sub-category cannot be restored while something above it is
  archived.
- Reports: spending in a category at any depth counts for its top-level
  category.
- Budgets: a category budget counts spending in the category and everything
  inside it.
- Transaction filter: choosing a category matches it and everything inside it.
- Backup: nesting is kept and restored. CSV export writes the whole path
  (`Food > Groceries > Rice`); CSV import reads paths of any length up to five
  and creates the levels that are missing.

## Rules
- `maxCategoryDepth = 5` (a top-level category is level 1).
- A category has the type of its parent; the type never changes.
- A category cannot go inside itself or inside anything inside it.
- A category cannot go inside an archived parent. (An unchanged archived
  parent is not checked again, so a sub-category can still be renamed.)
- Moving a category must keep its whole tree within five levels.
- Names are unique among siblings (case-insensitive).
- Backup files with a loop, a missing parent or a tree deeper than five levels
  are rejected as damaged. Restore inserts parents before children and deletes
  from the innermost level out.
- SQL uses one shared recursive CTE (`categoryTreeCte`), which stops by itself
  on a loop (`UNION`, not `UNION ALL`).

## Tests
- `test/features/categories/domain/category_tree_test.dart` - tree building,
  flattening, paths, descendants, levels, `categoryParentProblem`.
- `test/features/categories/data/categories_repository_test.dart` - creating,
  moving, depth limit, archive/restore of a whole subtree.
- `test/features/categories/data/category_depth_data_test.dart` - reports,
  budgets, backup round trip, restore over nested rows, CSV export/import of
  deep paths.
- `test/features/categories/presentation/categories_screen_test.dart` -
  indentation, "Add sub-category" limit, parent list, moving with children.
- `test/features/transactions/domain/transaction_filter_test.dart` - category
  scope.
- `test/features/backup/domain/backup_data_test.dart`,
  `test/features/backup/domain/import_plan_test.dart` - validation and paths.
