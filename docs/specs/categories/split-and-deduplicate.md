# Split categories, one place for each thing

Phone feedback (2026-11-06): "combined categories gulo alada kore felo", "jaja
duplicate ache merge koro", "aro tree korte paro".

## Behaviour
- **Nothing is two things at once.** Every default that joined two things with
  `&` or `,` is now side by side siblings: Bus and Rickshaw, Flour, Sugar and
  Salt, Shirt and Panjabi, Hospital and Surgery, bKash charge and Nagad
  charge... A group may still have `&` in its name (*Snacks & tea*, *Bills &
  utilities*) because it holds the things it names.
- **A thing is in one place only, by what the money was for.** Medicine is in
  Health, clothes (also kids wear, jewellery) in Shopping, gifts in *Family &
  gifts > Gifts* (Salami, Eid, Birthday, Wedding, Gaye holud, Anniversary),
  pocket money in *Pocket money > Wife / Husband / Children*, monthly help in
  *Monthly support > Parents / Siblings / In-laws / Relatives*. WHO it was for is
  a **tag** (Trips & events), not another copy of the tree.
- **Deeper tree** where it helps: Food > Kacha bazar > Fish > Hilsa / Rui /
  Katla / Small fish; Beef, Mutton, Chicken; Transport > Own vehicle > Parking,
  Toll, Tyre.
- Income too: Eid bonus and Festival bonus, Farming > Crops / Livestock, Pension
  and Allowance, Refund and Cashback as their own categories.

## Older installs (schema 19, `refreshDefaultCategories`)
- Only an install made with the defaults is touched (it has *Food > Kacha
  bazar*). A category the person renamed is not recognised and is left alone.
- An old default that is no longer a default is **archived only when nothing
  uses it** (no transaction, budget, repeating entry or challenge) and nothing
  active sits inside it. One that has history stays exactly as it is.
- Then the defaults the install does not have are added (the same as *Add the
  Bangladesh categories*), so *Bus* and *Rickshaw* appear next to an old *Bus &
  rickshaw* that has history.
- The old list is frozen in `legacy_defaults.dart`; never edit it.
- Data check lists a combined category next to the split ones in the same place
  (*Bus & rickshaw* with *Bus*), so the person can Merge it by hand: only they
  know if an old entry was a bus or a rickshaw.

## Tests
`test/core/database/category_fixes_test.dart` (the rules for the defaults and
the schema 19 refresh), `test/features/data_check/domain/data_check_test.dart`,
`test/features/categories/data/parent_suggestion_test.dart`.
