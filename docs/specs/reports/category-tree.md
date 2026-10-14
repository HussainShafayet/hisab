# Where the money went, down the category tree

## Goal
See how much went to each category, with every group showing the total of
everything inside it: Food = Food itself + Kacha bazar + Fish + the rest.

## Behaviour
- A card on Reports, under the pie chart, for the period chosen at the top of
  the screen. Its title is "Where the money went" (expense) or "Where the money
  came from" (income), with an Expense / Income switch.
- The top level is listed biggest first. A group shows an arrow; tapping its
  row opens it to show the categories inside, which open the same way, down as
  far as the tree goes. "Open all" / "Close all" does every group at once.
- Each row has the category icon, its name, its total, a bar and the share of
  the whole period (bar and percentage are of the period total, so a category
  inside a group is a smaller bar than its group).
- A group that has money of its own as well as categories inside shows a
  "Directly in Food" row first when open, so the rows inside add up to the
  group.
- Categories with no money anywhere inside are left out. An archived category
  that has money in the period still shows. Balance corrections and transfers
  are not counted, like everywhere else.

## Rules
- `ReportsDao.ownTotalsByCategory` is the money put directly on each category.
  `buildBranches(categories, own)` rolls it up: total = own + totals of the
  children; zero totals dropped; biggest first, ties by name.
- The top-level totals equal the pie chart's, since both are of the same money.
- Long amounts shrink to fit a small phone.

## Tests
- `test/features/reports/domain/category_branch_test.dart`
- `test/features/reports/data/category_branches_test.dart`
- `test/features/reports/presentation/category_tree_card_test.dart`
