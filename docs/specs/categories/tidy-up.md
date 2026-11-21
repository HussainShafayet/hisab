# A group for each person, and merging doubled categories

Phone feedback (2026-11-08): "category gulo ekhono duplicate roye gese. Merge
korte hobe. Family's er moddhe wife, children er jonnno tree banao. Related aro
kisu thakle banao."

## The people of the house
*Family & gifts* has a group for each person, holding only what belongs to that
person. What every person has (Clothes, Medicine, Doctor, Gifts, Outings,
Jewellery, Cosmetics, Parlour) is kept once, in its own place: *Shopping >
Clothing (> Jewellery)*, *Health > Medicine*, *Health > Doctor & tests > Doctor
visit*, *Family & gifts > Gifts*, *Entertainment > Outings*, *Personal care >
Cosmetics / Parlour*. Only *Pocket money* repeats, on purpose: it says who got
the money. (Changed 2026-11-21: "similar type er gulo different layer e na
rekhe merge kore felo".)
- **Wife**: Pocket money, Pregnancy checkup, Delivery.
- **Husband**: Pocket money.
- **Children**: Pocket money, Baby food, Diapers, Toys, Treats, Vaccine,
  Birthday party.
- **Family events** (new): Aqiqah, Khatna, Wedding, Milad, Funeral.
- Kept as they were: Monthly support (Parents, Siblings, In-laws, Relatives),
  Education help, Visits home, Gifts (Salami, Eid, Birthday, Wedding...).
- The old *Pocket money > Wife / Husband / Children* group is gone from the
  defaults: each person has their own *Pocket money*.

## Tidy-up (`CategoryTidy`, schema 20 and 21, and the wand button on Categories)
Runs once on updating to schema 20 and again to schema 21 (`tidyCategories`,
which never stops the app when it fails) and on demand with **Merge doubled categories**
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
3. **One place for each thing** (`personRepeats`, schema 21): *Clothes, Medicine,
   Doctor, Gifts, Outings, Jewellery, Cosmetics, Parlour* inside *Wife / Husband
   / Children* are folded into the place above, with their entries, budgets and
   what is inside them. A repeat whose place is gone (renamed or deleted) stays.
4. **Look-alikes in other layers** (`mergeLookalikes`, schema 21): two active
   categories of one type whose names are the same words (case, "&"/"and",
   order and a plural s ignored: *Gifts* / *Gift*, *Medicine & doctor* / *Doctor
   and medicine*), wherever they sit, become one. The one closest to the top
   stays (then the one with more transactions); what is inside the other moves
   into it. Left alone: a group and its own part, anything inside a person's
   group, expense vs income, and generic names (*Other*, *Others*, *Misc*,
   *General*, ...), which mean something else in each place.
5. An install made with the defaults (it has *Food > Kacha bazar*) then gets the
   categories it lacks, as *Add them* does. A custom install gets nothing added.
Names that only share a word (*Bus & rickshaw* and *Bus*) are not merged: only
the person knows what an old entry was (Data check shows them). A merge cannot be
undone; **Backup & export first** when updating.

## Tests
`test/features/categories/data/category_tidy_test.dart`,
`test/core/database/category_fixes_test.dart`,
`test/core/database/migration_test.dart` (schema 20 and 21).
