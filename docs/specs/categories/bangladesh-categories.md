# Everyday Bangladesh categories

## Goal
The default categories match daily life in Bangladesh (kacha bazar, rickshaw,
tuition, salami, fitra), the busiest ones go down a few levels, and the app
helps place a new category so no one has to guess which goes inside which.

## Behaviour
- **The defaults** are a tree: Food > Kacha bazar > Fish, Transport > City
  travel > CNG & auto, Bills & utilities > Electricity > Prepaid meter
  recharge, and so on, for Food, Transport, Bills, House help, Health,
  Education, Shopping, Family, Festivals, Entertainment, Charity, Savings and
  Fees; income has Salary, Tuition income, Remittance, Farming and more.
  Icons and colors are handed down from the group unless a category has its own.
- **A fresh install** gets all of them.
- **An older install** shows an "Everyday Bangladesh categories" card under
  the list on the Categories screen with how many are missing and an "Add them"
  button. Adding changes nothing that exists and never brings back what was
  archived (nor what would go inside an archived group).
- **A big tree** (more than 40 rows) opens with the top level open and the
  groups inside those closed; a small tree opens fully.
- **Placing a new category**: in the category form, while the name is typed
  and no group is chosen, a banner says "Looks like it goes inside X." with a
  "Put it there" button (it also takes the group's icon and color if they are
  still the defaults). The "Inside" field explains itself ("The bigger group it
  belongs to, like Food for Fuchka").

## Rules
- `DefaultCategory` is recursive; `flattenDefaults` lists every default with its
  path, icon and color, parents first. The depth stays within `maxCategoryDepth`.
- `missingDefaults(existing)` compares names without case, by where they sit
  (a path of names), so "Fish" inside Food is not "Fish" inside Kacha bazar.
- `suggestParent` first looks for the typed name among the defaults, then for
  everyday words (a table of path and words, specific rows first). It suggests
  the deepest category on the path that exists and is not archived, else the
  nearest one above it; nothing when the name is already used, too short or fits
  nowhere. Words match whole, or start with a keyword of 4 letters or more.

## Tests
- `test/features/categories/data/category_pack_test.dart`
- `test/features/categories/data/category_pack_repository_test.dart`
- `test/features/categories/data/parent_suggestion_test.dart`
- `test/features/categories/presentation/categories_pack_ui_test.dart`
- `test/features/categories/presentation/parent_suggestion_ui_test.dart`
- `test/core/database/seed_data_test.dart`
