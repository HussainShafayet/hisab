# A group for each person, and merging doubled categories

Phone feedback (2026-11-08): "category gulo ekhono duplicate roye gese. Merge
korte hobe. Family's er moddhe wife, children er jonnno tree banao. Related aro
kisu thakle banao."

## The people of the house
*Family & gifts* has a group for each person, holding what is spent on them (the
path tells two *Clothes* apart, so the same name in two people is on purpose):
- **Wife**: Pocket money, Clothes, Jewellery, Cosmetics, Parlour, Medicine,
  Doctor, Pregnancy checkup, Delivery, Gifts, Outings.
- **Husband**: Pocket money, Clothes, Medicine, Doctor, Gifts, Outings.
- **Children**: Pocket money, Baby food, Diapers, Toys, Treats, Clothes,
  Medicine, Doctor, Vaccine, Birthday party, Gifts, Outings.
- **Family events** (new): Aqiqah, Khatna, Wedding, Milad, Funeral.
- Kept as they were: Monthly support (Parents, Siblings, In-laws, Relatives),
  Education help, Visits home, Gifts (Salami, Eid, Birthday, Wedding...).
- The old *Pocket money > Wife / Husband / Children* group is gone from the
  defaults: each person has their own *Pocket money*.

## Tidy-up (`CategoryTidy`, schema 20, and the wand button on Categories)
Runs once on updating to schema 20 (`tidyCategories`, which never stops the app
when it fails) and on demand with **Merge doubled categories**
(`tidy-categories`, with a question first). No transaction is ever lost.
1. **Family by person** (`familyByPerson`): *Pocket money > Wife* becomes *Wife >
   Pocket money* (same row, so its entries and budgets stay); the group is made
   when missing. Where the person already has a *Pocket money* (the old
   *Children > Pocket money*), the two are merged. The empty *Pocket money*
   group is archived when nothing is attached to it. Anything the person built in
   there that a merge cannot take (sub-categories in use) is left as it is.
2. **Doubles** (`mergeDoubles`): two active categories of one type, in the same
   place, with the same name (case and spaces ignored) become one. The one with
   more transactions stays; what is inside the other moves into it, and the
   doubles that makes are merged in turn. Same name in two *places* is left
   alone.
3. An install made with the defaults (it has *Food > Kacha bazar*) then gets the
   categories it lacks, as *Add them* does. A custom install gets nothing added.
Names that only look alike (*Bus & rickshaw* and *Bus*) are not merged: only the
person knows what an old entry was (Data check shows them).

## Tests
`test/features/categories/data/category_tidy_test.dart`,
`test/core/database/category_fixes_test.dart`,
`test/core/database/migration_test.dart` (schema 20).
